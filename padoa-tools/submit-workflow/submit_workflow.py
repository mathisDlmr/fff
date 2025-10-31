import json
from modules.argo_workflows.api import Workflow
from modules.argo_workflows.api import WorkflowStatus
from modules.argo_workflows.api import PollingTimeoutException, WorkflowFailedException
import os
import logging
from datetime import datetime, timezone
import time
import requests
from requests.exceptions import HTTPError, RequestException

WAIT_FOR_COMPLETION             = os.getenv('WAIT_FOR_COMPLETION', "false").lower() in ["1", "true"]
NAMESPACE                       = os.environ['NAMESPACE']
WORKFLOW_NAME                   = os.getenv('WORKFLOW_NAME', None)
WORKFLOW_TEMPLATE_NAME          = os.environ['WORKFLOW_TEMPLATE_NAME']
WORKFLOW_TEMPLATE_ENTRYPOINT    = os.getenv('WORKFLOW_TEMPLATE_ENTRYPOINT')
SUBMIT_OPTIONS                  = json.loads(os.getenv('SUBMIT_OPTIONS', '{}'))
REATTACH_TO_RUNNING             = os.getenv('REATTACH_TO_RUNNING', "true").lower() in ["1", "true"]

# Retry configuration
MAX_RETRIES = int(os.getenv('MAX_RETRIES', '3'))
INITIAL_RETRY_DELAY = float(os.getenv('INITIAL_RETRY_DELAY', '1.0'))
MAX_RETRY_DELAY = float(os.getenv('MAX_RETRY_DELAY', '60.0'))
RETRY_BACKOFF_MULTIPLIER = float(os.getenv('RETRY_BACKOFF_MULTIPLIER', '2.0'))
RETRYABLE_STATUS_CODES = [408, 429, 500, 502, 503, 504, 524, 598, 599]

if WORKFLOW_NAME is not None:
    if SUBMIT_OPTIONS.get("generateName") is not None:
        SUBMIT_OPTIONS["generateName"] = WORKFLOW_NAME
        SUBMIT_OPTIONS["name"] = None
    else:
        SUBMIT_OPTIONS["name"] = WORKFLOW_NAME

TIMEOUT = int(os.getenv('TIMEOUT', str(12 * 60 * 60))) # 12h
INTERVAL = int(os.getenv('INTERVAL', str(60)))
MAX_DURATION_TO_REATTACH = int(os.environ.get('MAX_DURATION_TO_REATTACH',60*60*6)) #6h

logger = logging.getLogger(__name__)
logger.setLevel(int(os.getenv("LOGGING", logging.INFO)))
console_handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

def should_retry_error(error):
    """Determine if an error should trigger a retry."""
    if isinstance(error, HTTPError):
        return error.response.status_code in RETRYABLE_STATUS_CODES
    elif isinstance(error, RequestException):
        # Network errors, timeouts, etc.
        return True
    return False

def get_retry_delay(attempt, initial_delay, max_delay, backoff_multiplier):
    """Calculate delay for retry with exponential backoff."""
    delay = initial_delay * (backoff_multiplier ** (attempt - 1))
    return min(delay, max_delay)

def retry_with_backoff(func, *args, **kwargs):
    """Execute a function with retry logic and exponential backoff."""
    last_exception = None

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            last_exception = e

            if not should_retry_error(e) or attempt >= MAX_RETRIES:
                logger.error(f"Final attempt {attempt} failed: {str(e)}")
                raise e

            delay = get_retry_delay(attempt, INITIAL_RETRY_DELAY, MAX_RETRY_DELAY, RETRY_BACKOFF_MULTIPLIER)

            if isinstance(e, HTTPError):
                logger.warning(f"Attempt {attempt} failed with HTTP {e.response.status_code}: {str(e)}. Retrying in {delay:.1f}s...")
            else:
                logger.warning(f"Attempt {attempt} failed: {str(e)}. Retrying in {delay:.1f}s...")

            time.sleep(delay)

    # This should never be reached, but just in case
    raise last_exception

def check_duration_since_date(time: str, maxDuration: int):
    datetime_time = datetime.fromisoformat(time.replace("Z", "+00:00"))
    now = datetime.now(timezone.utc)
    duration = now - datetime_time
    return duration.total_seconds() < maxDuration

def retrieve_running_workflows_with_retry(namespace: str, workflow_name: str, logger: logging.Logger):
    """Retrieve running workflows with retry logic."""
    wfs = Workflow.retrieve_running_workflows(namespace=namespace, logger=logger)
    if wfs['items'] is not None:
        for item in wfs['items']:
            if item is not None:
                name = item['metadata']['name']
                logger.info(f"Checking workflow {name} for match with {workflow_name}")
                if name and name.startswith(workflow_name) and check_duration_since_date(item['status']['startedAt'], MAX_DURATION_TO_REATTACH):
                    logger.info(f"Found running workflow {name}")
                    return name
    else:
        logger.info(f"No running workflows found in namespace {namespace}")
        return None

def get_existing_running_wf(namespace: str, workflow_name: str, logger: logging.Logger):
    if not workflow_name:
        logger.info(f"Workflow name not provided, skipping check for existing running workflow will not reattach")
        return None

    try:
        return retry_with_backoff(retrieve_running_workflows_with_retry, namespace, workflow_name, logger)
    except Exception as e:
        logger.warning(f"Failed to retrieve running workflows, will proceed with new workflow creation: {str(e)}")
        return None

def create_workflow_from_template(namespace: str, template_name: str, submit_options: dict, entrypoint: str, logger: logging.Logger):
    """Create a new workflow from template with retry logic."""
    return Workflow.from_workflow_template(
        namespace,
        template_name,
        submit_options={
            **submit_options,
            **({"entrypoint": entrypoint} if entrypoint is not None else {}),
        },
        logger=logger
    )

existing = get_existing_running_wf(namespace=NAMESPACE, workflow_name=WORKFLOW_NAME, logger=logger) if REATTACH_TO_RUNNING else None

if existing is not None:
    WORKFLOW_NAME = existing
    try:
        alreadyExistingWorkflow = retry_with_backoff(
            Workflow.from_existing_workflow,
            namespace=NAMESPACE,
            workflow_name=WORKFLOW_NAME,
            logger=logger
        )
        if alreadyExistingWorkflow.status == "Running":
            logger.info(f"Attached to existing running workflow: {WORKFLOW_NAME}")
            workflow = alreadyExistingWorkflow
        else:
            logger.info(f"Existing workflow {WORKFLOW_NAME} is not running, will create new workflow")
            existing = None
    except Exception as e:
        logger.warning(f"Failed to attach to existing workflow {WORKFLOW_NAME}, will create new workflow: {str(e)}")
        existing = None

if existing is None:
    logger.info(f"No existing workflow for name {WORKFLOW_TEMPLATE_NAME} or exists but not running, launching new workflow")

    workflow = retry_with_backoff(
        create_workflow_from_template,
        NAMESPACE,
        WORKFLOW_TEMPLATE_NAME,
        SUBMIT_OPTIONS,
        WORKFLOW_TEMPLATE_ENTRYPOINT,
        logger
    )

if WAIT_FOR_COMPLETION:
    try:
        workflow.wait_for_completion(
            INTERVAL, TIMEOUT).raise_for_status()
    except Exception as e:
        logger.error(f"Workflow execution failed: {str(e)}")
        raise e
