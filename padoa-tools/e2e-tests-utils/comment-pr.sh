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

if [ -z "$COMMENT" ]
then
  echo "[ERROR] COMMENT is missing"
  exit 1
fi

BODY="{\"body\":\"$COMMENT\"}"

echo "$BODY" | curl -v -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPOSITORY_URL/issues/$ISSUE_NUMBER/comments \
  --data-binary @-
