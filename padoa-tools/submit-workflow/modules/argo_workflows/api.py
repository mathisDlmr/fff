import requests
import os
from enum import Enum
import time
import logging

from requests.exceptions import HTTPError
from requests.adapters import HTTPAdapter, Retry

HOST = os.environ['ARGO_WORKFLOW_HOST']

TOKEN = os.getenv('ARGO_WORKFLOW_TOKEN')
headers = ({"Authorization": TOKEN} if TOKEN is not None else {})

MAX_HTTP_RETRY_COUNT = int(os.environ.get('MAX_HTTP_RETRY_COUNT', '0'))
BACKOFF = int(os.getenv('BACKOFF', '1'))

session = requests.session()

retry_strategy = Retry(
    total=MAX_HTTP_RETRY_COUNT,
    backoff_factor=BACKOFF,
    status_forcelist=[500, 502, 503, 504, 524], 
)

adapter = HTTPAdapter(max_retries=retry_strategy)
session.mount("http://", adapter)
session.mount("https://", adapter)
session.headers.update(headers)

PROTOCOL = os.getenv('PROTOCOL', 'https')

PORT = os.getenv('ARGO_WORKFLOW_PORT', ("443" if PROTOCOL == 'https' else "80"))

STOP_IF_TIMEOUT = os.getenv('STOP_IF_TIMEOUT', False)

class WorkflowStatus(Enum):
    RUNNING     = "Running"
    UNKNOWN     = "Unknown"

    SUCCEEDED   = "Succeeded"
    FAILED      = "Failed"
    ERROR       = "Error"

class BaseWorkflowException(Exception):
    def __init__(self, workflow):
        self.workflow = workflow

class WorkflowFailedException(BaseWorkflowException):
    def __str__(self):
        return f'Workflow in status {self.workflow.status}'


class PollingTimeoutException(Exception):
    pass


class WorkflowNotFoundException(Exception):
    pass


class WorkflowActionException(BaseWorkflowException):
    def __init__(self, workflow, action):
        self.action = action
        super().__init__(workflow)

    def __str__(self):
        return f'Workflow in status {self.workflow.status} cannot receive action {self.action}'


def _build_url(
    path: str,
    logger: logging.Logger
):
    url = f'{PROTOCOL}://{HOST}:{PORT}{path}'
    logger.debug(f"Url built : '{url}'")
    return url


class Workflow(object):

    def __init__(
        self,
        workflow_info: dict,
        logger: logging.Logger
    ):
        self._update_info_from_workflow_object(workflow_info)
        self.logger = logger



    def _update_info_from_workflow_object(self, workflow_info: dict):
        self.info = workflow_info
        # Extract some info to make them more easily accessible
        self.name = self.info["metadata"]["name"]
        self.namespace = self.info["metadata"]["namespace"]
        self.status = self.info["status"]["phase"] if "phase" in self.info["status"] else WorkflowStatus.UNKNOWN
        self.generation = self.info["metadata"]["generation"]

        return self

    @classmethod
    def from_workflow_template(cls, namespace: str, template_name: str, logger: logging.Logger = logging, submit_options={}, dry_run=False):
        logger.info(
            f"Trying to create workflow {template_name} in namespace {namespace}")
        workflow_creation_info = session.post(
            _build_url(f"/api/v1/workflows/{namespace}/submit", logger),
            
            json={
                "resourceKind": "WorkflowTemplate",
                "resourceName": template_name,
                "submitOptions": {
                    "serverDryRun": dry_run,
                    **submit_options
                }},
        )
        print(workflow_creation_info.request.body)
        logger.debug(
            f"Making {workflow_creation_info.request.method} call to {workflow_creation_info.request.url} : {workflow_creation_info.request.body}")
        workflow_creation_info.raise_for_status()
        workflow = cls(workflow_creation_info.json(), logger)
        logger.info(
            f"{workflow.namespace}.{workflow.name}: Created")
        return workflow

    def retrieve_running_workflows(namespace: str, logger: logging.Logger=logging):
        logger.info(
            f"Trying to retrieve all workflows from namespace {namespace}")
        workflows = session.get(
            _build_url(f"/api/v1/workflows/{namespace}?listOptions.limit=20&listOptions.labelSelector=workflows.argoproj.io/phase=Running&fields=items.metadata.name,items.status.startedAt",
                        logger),
            
        )
        try:
            workflows.raise_for_status()
        except HTTPError as http_error:
            if http_error.response.status_code == 404:
                raise WorkflowNotFoundException
            raise http_error
        return workflows.json()

    @classmethod
    def from_existing_workflow(cls, namespace: str, workflow_name: str, logger: logging.Logger = logging):
        logger.info(
            f"Trying to retrieve existing workflow {workflow_name} from namespace {namespace}")
        workflow_info = session.get(
            _build_url(f"/api/v1/workflows/{namespace}/{workflow_name}", logger),
            
        )

        try:
            workflow_info.raise_for_status()
        except HTTPError as http_error:
            if http_error.response.status_code == 404:
                raise WorkflowNotFoundException
            raise http_error

        workflow = cls(workflow_info.json(), logger)
        logger.info(
            f"{workflow.namespace}.{workflow.name}: Found")
        return workflow

    def stop(self):
        retry_response = session.put(
            _build_url(
                f"/api/v1/workflows/{self.namespace}/{self.name}/stop", self.logger),
            
        )
        retry_response.raise_for_status()
        self._update_info_from_workflow_object(retry_response.json())
        self.logger.info(
            f"{self.namespace}.{self.name}: Stopped")
        
    def retry(self):
        if not(self.update_info_from_remote().is_failed()):
            raise WorkflowActionException(self, 'retry')
        retry_response = session.put(
            _build_url(
                f"/api/v1/workflows/{self.namespace}/{self.name}/retry", self.logger),
            
        )
        retry_response.raise_for_status()
        self._update_info_from_workflow_object(retry_response.json())
        self.logger.info(
            f"{self.namespace}.{self.name}: Retried")

    def update_info_from_remote(self):
        workflow_info = session.get(
                    _build_url(f"/api/v1/workflows/{self.namespace}/{self.name}", self.logger),
                )
        workflow_info.raise_for_status()

        self._update_info_from_workflow_object(workflow_info.json())

        return self

    def is_complete(self):
        return WorkflowStatus(self.status) not in [WorkflowStatus.RUNNING, WorkflowStatus.UNKNOWN]

    def is_failed(self):
        return WorkflowStatus(self.status) in [WorkflowStatus.ERROR, WorkflowStatus.FAILED]

    def wait_for_completion(
        self,
        polling_period_seconds: int,
        polling_timeout_seconds: int,
    ):
        polling_duration = 0
        while not self._has_completed() and polling_duration < polling_timeout_seconds:
            self.logger.info(
                f"{self.namespace}.{self.name}: Completion polling is still running... ({polling_duration}s elapsed)")
            time.sleep(polling_period_seconds)
            polling_duration += polling_period_seconds

        if polling_duration >= polling_timeout_seconds:
            if STOP_IF_TIMEOUT:
                self.stop()
            raise PollingTimeoutException()
        self.logger.info(
            f"{self.namespace}.{self.name}: Completion polling completed")
        return self

    def _has_completed(self):
        return self.update_info_from_remote().is_complete()

    def raise_for_status(self):
        if WorkflowStatus(self.status) in [WorkflowStatus.ERROR, WorkflowStatus.FAILED]:
            raise WorkflowFailedException(self)
        return self
