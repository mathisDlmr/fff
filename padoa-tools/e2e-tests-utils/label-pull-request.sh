#!/bin/sh

if [ -z "$TOKEN" ]
then
  echo "[ERROR] TOKEN is missing"
  exit 1
fi

if [ -z "$ISSUE_NUMBER" ]
then
  echo "[ERROR] ISSUE_NUMBER is missing"
  exit 1
fi

if [ -z "$REPOSITORY_URL" ]
then
  echo "[ERROR] REPOSITORY_URL is missing"
  exit 1
fi

if [ -z "$LABEL_TO_ADD" ] && [ -z "$LABEL_TO_REMOVE" ]
then
  echo "[ERROR] At least one of LABEL_TO_ADD or LABEL_TO_REMOVE must be set"
  exit 1
fi

if [ -n "$LABEL_TO_REMOVE" ]; then

  curl -v -L \
    -X DELETE \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$REPOSITORY_URL/issues/$ISSUE_NUMBER/labels/$LABEL_TO_REMOVE

fi

if [ -n "$LABEL_TO_ADD" ]; then
  BODY="{\"labels\":[\"$LABEL_TO_ADD\"]}"

  curl -v -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$REPOSITORY_URL/issues/$ISSUE_NUMBER/labels \
    -d "$BODY"
fi




