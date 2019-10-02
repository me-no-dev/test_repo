#!/bin/bash
set -e

if [ ! $GITHUB_EVENT_NAME == "release" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

EVENT_JSON=`cat $GITHUB_EVENT_PATH`
action=`echo $EVENT_JSON | jq -r '.action'`
draft=`echo $EVENT_JSON | jq -r '.release.draft'`
prerelease=`echo $EVENT_JSON | jq -r '.release.prerelease'`
tag=`echo $EVENT_JSON | jq -r '.release.tag_name'`
branch=`echo $EVENT_JSON | jq -r '.release.target_commitish'`
release_id=`echo $EVENT_JSON | jq -r '.release.id'`

echo "Event: $GITHUB_EVENT_NAME, Repo: $GITHUB_REPOSITORY, Path: $GITHUB_WORKSPACE, Ref: $GITHUB_REF"
echo "Action: $action, Branch: $branch, ID: $release_id" 
echo "Tag: $tag, Draft: $draft, Pre-Release: $prerelease"

if [ $draft == "true" ]; then
	echo "It's a draft release. Exiting now..."
	exit 0
fi

if [ ! $action == "published" ]; then
	echo "Wrong action '$action'. Exiting now..."
	exit 0
fi

function get_file_size(){
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        eval `stat -s "$file"`
        local res="$?"
        echo "$st_size"
        return $res
    else
        stat --printf="%s" "$file"
        return $?
    fi
}

function git_upload_asset(){
    local name=$(basename "$1")
    # local mime=$(file -b --mime-type "$1")
    curl -k -X POST -sH "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/octet-stream" --data-binary @"$1" "https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/$RELEASE_ID/assets?name=$name"
}

function git_upload_to_pages(){
    local path=$1
    local src=$2

    if [ ! -f "$src" ]; then
        >&2 echo "Input is not a file! Aborting..."
        return 1
    fi

    local info=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.object+json" -X GET "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/$path?ref=gh-pages"`
    local type=`echo "$info" | jq -r '.type'`
    local message=$(basename $path)
    local sha=""
    local content=""

    if [ $type == "file" ]; then
        sha=`echo "$info" | jq -r '.sha'`
        sha=",\"sha\":\"$sha\""
        message="Updating $message"
    elif [ ! $type == "null" ]; then
        >&2 echo "Wrong type '$type'"
        return 1
    else
        message="Creating $message"
    fi

    content=`base64 -i "$src"`
    data="{\"branch\":\"gh-pages\",\"message\":\"$message\",\"content\":\"$content\"$sha}"

    echo "$data" | curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" -X PUT --data @- "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/$path"
}

function git_safe_upload_asset(){
    local file="$1"
    local name=$(basename "$file")
    local size=`get_file_size "$file"`
    set +e
    local upload_res=`git_upload_asset "$file"`
    if [ $? -ne 0 ]; then 
        >&2 echo "ERROR: Failed to upload '$name' ($?)"
        set -e
        return 1
    fi
    set -e
    up_size=`echo "$upload_res" | jq -r '.size'`
    if [ $up_size -ne $size ]; then
        >&2 echo "ERROR: Uploaded size does not match! $up_size != $size"
        return 1
    fi
    echo "$upload_res" | jq -r '.browser_download_url'
    return $?
}

function git_safe_upload_to_pages(){
    local path=$1
    local file="$2"
    local name=$(basename "$file")
    local size=`get_file_size "$file"`
    set +e
    local upload_res=`git_upload_to_pages "$path" "$file"`
    if [ $? -ne 0 ]; then 
        >&2 echo "ERROR: Failed to upload '$name' ($?)"
        set -e
        return 1
    fi
    set -e
    up_size=`echo "$upload_res" | jq -r '.content.size'`
    if [ $up_size -ne $size ]; then
        >&2 echo "ERROR: Uploaded size does not match! $up_size != $size"
        return 1
    fi
    echo "$upload_res" | jq -r '.content.download_url'
    return $?
}

# good time to build the assets
if [ $prerelease == "true" ]; then
	echo "It's a pre-release"
fi

# upload asset to the release page
git_safe_upload_asset ./README.md

# upload file to github pages
git_safe_upload_to_pages README.md ./README.md
