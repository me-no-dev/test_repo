#!/bin/bash

if [ ! $GITHUB_EVENT_NAME == "release" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

echo "Event: $GITHUB_EVENT_NAME, Repo: $GITHUB_REPOSITORY, Path: $GITHUB_WORKSPACE, Ref: $GITHUB_REF"

EVENT_JSON=`cat $GITHUB_EVENT_PATH`

# Release Actions [published]
action=`echo $EVENT_JSON | jq -r '.action'`
draft=`echo $EVENT_JSON | jq -r '.release.draft'`
prerelease=`echo $EVENT_JSON | jq -r '.release.prerelease'`
tag=`echo $EVENT_JSON | jq -r '.release.tag_name'`
branch=`echo $EVENT_JSON | jq -r '.release.target_commitish'`
id=`echo $EVENT_JSON | jq -r '.release.id'`

echo "Action: $action, Branch: $branch, ID: $id" 
echo "Tag: $tag, Draft: $draft, Pre-Release: $prerelease"

if [ $draft == "true" ]; then
	echo "It's a draft release. Exiting now..."
	exit 0
fi

if [ ! $action == "published" ]; then
	echo "Wrong action '$action'. Exiting now..."
	exit 0
fi

function git_upload_asset(){
    local name=$(basename "$1")
    local mime=$(file -b --mime-type "$1")
    curl -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" -H "Content-Type: $mime" --data "@$1" "https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/$id/assets?name=$name"
}

#good time to build the assets

git_upload_asset ./README.md
