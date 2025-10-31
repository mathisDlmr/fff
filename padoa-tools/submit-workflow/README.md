# Submit Workflow

A Python script for submitting Argo Workflows with enhanced retry capabilities and error handling.

## Features

- Submit workflows from workflow templates
- Reattach to existing running workflows
- Wait for workflow completion
- **Enhanced retry logic** with exponential backoff for transient errors
- Comprehensive error handling for HTTP errors (including 524 timeout errors)
- Configurable retry parameters

## Retry Configuration

The script now includes robust retry functionality to handle transient errors like HTTP 524 (Gateway Timeout) and other network issues:

### Environment Variables for Retry Logic

- `MAX_RETRIES` (default: 3): Maximum number of retry attempts
- `INITIAL_RETRY_DELAY` (default: 1.0): Initial delay in seconds before first retry
- `MAX_RETRY_DELAY` (default: 60.0): Maximum delay between retries in seconds
- `RETRY_BACKOFF_MULTIPLIER` (default: 2.0): Multiplier for exponential backoff

### Retryable Error Codes

The script automatically retries on the following HTTP status codes:
- 408 (Request Timeout)
- 429 (Too Many Requests)
- 500 (Internal Server Error)
- 502 (Bad Gateway)
- 503 (Service Unavailable)
- 504 (Gateway Timeout)
- 524 (Cloudflare Timeout)
- 598 (Network Read Timeout)
- 599 (Network Connect Timeout)

### Retry Behavior

- **Exponential Backoff**: Delay increases exponentially between retries
- **Smart Retry Logic**: Only retries on transient errors, not on permanent failures
- **Comprehensive Logging**: Detailed logging of retry attempts and delays
- **Graceful Degradation**: Falls back to new workflow creation if reattachment fails

## Usage

### Basic Usage

```bash
export NAMESPACE="your-namespace"
export WORKFLOW_TEMPLATE_NAME="your-template"
export ARGO_WORKFLOW_HOST="your-argo-host"
export ARGO_WORKFLOW_TOKEN="your-token"

python submit_workflow.py
```

### With Retry Configuration

```bash
export MAX_RETRIES=5
export INITIAL_RETRY_DELAY=2.0
export MAX_RETRY_DELAY=120.0
export RETRY_BACKOFF_MULTIPLIER=3.0

python submit_workflow.py
```

### With Workflow Options

```bash
export WORKFLOW_NAME="my-workflow"
export SUBMIT_OPTIONS='{"generateName": "my-workflow-", "labels": {"env": "prod"}}'
export WAIT_FOR_COMPLETION="true"
export TIMEOUT=3600

python submit_workflow.py
```

## Environment Variables

### Required
- `NAMESPACE`: Kubernetes namespace for the workflow
- `WORKFLOW_TEMPLATE_NAME`: Name of the workflow template to use
- `ARGO_WORKFLOW_HOST`: Argo Workflows API host

### Optional
- `WORKFLOW_NAME`: Specific name for the workflow (overrides generateName)
- `WORKFLOW_TEMPLATE_ENTRYPOINT`: Entrypoint to use from the template
- `SUBMIT_OPTIONS`: JSON string of additional submit options
- `WAIT_FOR_COMPLETION`: Whether to wait for workflow completion (default: false)
- `TIMEOUT`: Timeout for workflow completion in seconds (default: 12 hours)
- `INTERVAL`: Polling interval in seconds (default: 60)
- `REATTACH_TO_RUNNING`: Whether to reattach to existing running workflows (default: true)
- `MAX_DURATION_TO_REATTACH`: Maximum age of workflows to reattach to in seconds (default: 6 hours)
- `LOGGING`: Log level (default: INFO)

### Retry Configuration
- `MAX_RETRIES`: Maximum retry attempts (default: 3)
- `INITIAL_RETRY_DELAY`: Initial retry delay in seconds (default: 1.0)
- `MAX_RETRY_DELAY`: Maximum retry delay in seconds (default: 60.0)
- `RETRY_BACKOFF_MULTIPLIER`: Backoff multiplier (default: 2.0)

## Error Handling

The script now provides robust error handling:

1. **Transient Errors**: Automatically retries with exponential backoff
2. **Permanent Errors**: Fails fast without retrying
3. **Network Issues**: Handles timeouts and connection problems
4. **Graceful Degradation**: Falls back to alternative approaches when possible

## Examples

### Handle 524 Timeout Errors

The script will automatically retry when encountering 524 (Gateway Timeout) errors:

```bash
export MAX_RETRIES=5
export INITIAL_RETRY_DELAY=2.0
python submit_workflow.py
```

### Custom Retry Strategy

For environments with high latency, you might want longer delays:

```bash
export MAX_RETRIES=7
export INITIAL_RETRY_DELAY=5.0
export MAX_RETRY_DELAY=300.0
export RETRY_BACKOFF_MULTIPLIER=2.5
python submit_workflow.py
```

## Dependencies

- Python 3.6+
- `requests` library
- Argo Workflows API access

## Troubleshooting

### Common Issues

1. **524 Timeout Errors**: The script now automatically retries these with exponential backoff
2. **Network Connectivity**: Retry logic handles temporary network issues
3. **API Rate Limiting**: 429 errors are automatically retried with backoff

### Logging

Enable debug logging to see detailed retry information:

```bash
export LOGGING=10  # DEBUG level
python submit_workflow.py
```

The script will log:
- Retry attempts and delays
- HTTP error codes and messages
- Fallback behavior when operations fail
