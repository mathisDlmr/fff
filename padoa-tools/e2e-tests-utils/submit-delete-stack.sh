#!/bin/sh

WORKFLOW_ID="delete-e2e-azure-stack.yml"

if [ -z "$TOKEN" ]
then
  echo "[ERROR] TOKEN is missing"
  exit 1
fi

if [ -z "$BRANCH_NAME" ]
then
  echo "[ERROR] BRANCH_NAME is missing"
  exit 1
fi

if [ -z "$REPOSITORY_URL" ]
then
  echo "[ERROR] REPOSITORY_URL is missing"
  exit 1
fi

if [ -z "$RUN_ID" ]
then
  echo "[ERROR] RUN_ID is missing"
  exit 1
fi

if [ -z "$SELECTED_RUNNER" ]
then
  echo "[ERROR] SELECTED_RUNNER is missing"
  exit 1
fi

# Cleanup prefix
SELECTED_RUNNER=${SELECTED_RUNNER#"micro-"}
# Add cleanup prefix
SELECTED_RUNNER="e2ecd-cleanup-$SELECTED_RUNNER"

# Replace e2ecd to e2e to target the assoicated e2e cleanup runner
SELECTED_E2E_RUNNER=$(echo "$SELECTED_RUNNER" | sed "s/e2ecd/e2e/g")


curl -v -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPOSITORY_URL/actions/workflows/$WORKFLOW_ID/dispatches \
  -d '{"ref":"'$BRANCH_NAME'","inputs":{"helm_release":"'$RUN_ID'","selected_runner":"'$SELECTED_RUNNER'", "selected_e2e_runner":"'$SELECTED_E2E_RUNNER'"}}'
