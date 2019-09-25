#!/bin/bash
EVENT_JSON=`cat $GITHUB_EVENT_PATH`

#GITHUB_REF=refs/tags/<tag> or refs/heads/<branch>

echo "Event: $GITHUB_EVENT_NAME, Repo: $GITHUB_REPOSITORY, Path: $GITHUB_WORKSPACE"

if [ $GITHUB_EVENT_NAME == "repository_dispatch" ]; then
    action=`echo $EVENT_JSON | jq -r '.action'`
    payload=`echo $EVENT_JSON | jq -r '.client_payload'`
    echo "Action: $action, Payload: $payload"
    exit 0
elif [ ! $GITHUB_EVENT_NAME == "release" ]; then
    echo
    echo $EVENT_JSON
    exit 0
fi

action=`echo $EVENT_JSON | jq -r '.action'`
assets_url=`echo $EVENT_JSON | jq -r '.release.assets_url'`
draft=`echo $EVENT_JSON | jq -r '.release.draft'`
prerelease=`echo $EVENT_JSON | jq -r '.release.prerelease'`
tag=`echo $EVENT_JSON | jq -r '.release.tag_name'`
branch=`echo $EVENT_JSON | jq -r '.release.target_commitish'`
id=`echo $EVENT_JSON | jq -r '.release.id'`

echo "Action: $action, Branch: $branch" 
echo "Tag: $tag, Draft: $draft, Pre-Release: $prerelease" 
echo "Assets: $assets_url" 
