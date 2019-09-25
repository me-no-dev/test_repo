#!/bin/bash
EVENT_JSON=`cat $GITHUB_EVENT_PATH`

echo $EVENT_JSON
echo

action=`echo $EVENT_JSON | jq -r '.action'`
assets_url=`echo $EVENT_JSON | jq -r '.release.assets_url'`
draft=`echo $EVENT_JSON | jq -r '.release.draft'`
prerelease=`echo $EVENT_JSON | jq -r '.release.prerelease'`
tag=`echo $EVENT_JSON | jq -r '.release.tag_name'`
branch=`echo $EVENT_JSON | jq -r '.release.target_commitish'`
id=`echo $EVENT_JSON | jq -r '.release.id'`

echo "Repo: $GITHUB_REPOSITORY, Path: $GITHUB_WORKSPACE"
echo "Event: $GITHUB_EVENT_NAME, Action: $action, Branch: $branch" 
echo "Tag: $tag, Draft: $draft, Pre-Release: $prerelease" 
echo "Assets: $assets_url" 
