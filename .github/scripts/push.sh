#!/bin/bash

if [ ! $GITHUB_EVENT_NAME == "push" ] && [ ! $GITHUB_EVENT_NAME == "pull_request" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

echo "Event: $GITHUB_EVENT_NAME, Repo: $GITHUB_REPOSITORY, Path: $GITHUB_WORKSPACE, Ref: $GITHUB_REF"

EVENT_JSON=`cat $GITHUB_EVENT_PATH`

# Pull Request Actions [opened, reopened, synchronize]
if [ $GITHUB_EVENT_NAME == "pull_request" ]; then
    action=`echo $EVENT_JSON | jq -r '.action'`
    mergeable_state=`echo $EVENT_JSON | jq -r '.pull_request.mergeable_state'`
    echo "Action: $action, Mergeable: $mergeable_state"
fi

mkdir -p build .tmp

pip install wheel
pip install PyInstaller pyserial

if [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
	pip install requests
fi

python -m PyInstaller --win-private-assemblies --distpath build --workpath .tmp -F tools/esptool.py
python -m PyInstaller --win-private-assemblies --distpath build --workpath .tmp -F tools/get.py
python -m PyInstaller --win-private-assemblies --distpath build --workpath .tmp -F tools/espota.py
python -m PyInstaller --win-private-assemblies --distpath build --workpath .tmp -F tools/gen_esp32part.py
