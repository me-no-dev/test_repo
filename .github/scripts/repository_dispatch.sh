#!/bin/bash

if [ ! $GITHUB_EVENT_NAME == "repository_dispatch" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

echo "Event: $GITHUB_EVENT_NAME, Repo: $GITHUB_REPOSITORY, Path: $GITHUB_WORKSPACE, Ref: $GITHUB_REF"

EVENT_JSON=`cat $GITHUB_EVENT_PATH`
action=`echo $EVENT_JSON | jq -r '.action'`
payload=`echo $EVENT_JSON | jq -r '.client_payload'`
echo "Action: $action, Payload: $payload"
