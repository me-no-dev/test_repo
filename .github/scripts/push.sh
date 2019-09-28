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

function get_os(){
  	local OSBITS=`arch`
  	if [[ "$OSTYPE" == "linux"* ]]; then
  		OS_IS_LINUX="1"
  		ARCHIVE_FORMAT="tar.xz"
        if [[ "$OSBITS" == "i686" ]]; then
        	OS_NAME="linux32"
        elif [[ "$OSBITS" == "x86_64" ]]; then
        	OS_NAME="linux64"
        elif [[ "$OSBITS" == "armv7l" ]]; then
        	OS_NAME="linuxarm"
        else
        	OS_NAME="$OSTYPE-$OSBITS"
	    	return 1
        fi
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		OS_IS_MACOS="1"
  		ARCHIVE_FORMAT="zip"
	    OS_NAME="macosx"
	elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
		OS_IS_WINDOWS="1"
  		ARCHIVE_FORMAT="zip"
	    OS_NAME="windows"
	else
	    OS_NAME="$OSTYPE-$OSBITS"
	    return 1
	fi
	return 0
}

get_os

#OSTYPE: 'linux-gnu', ARCH: 'x86_64' => linux64
#OSTYPE: 'msys', ARCH: 'x86_64' => win32
#OSTYPE: 'darwin18', ARCH: 'i386' => macos

if [ "$OS_IS_MACOS" == "1" ]; then
	ARDUINO_IDE_PATH="$HOME/Arduino.app/Contents/Java"
else
	ARDUINO_IDE_PATH="$HOME/arduino_ide"
fi
ARDUINO_USR_PATH="$HOME/Arduino"
ARDUINO_BUILD_DIR="$HOME/build.tmp"
ARDUINO_CACHE_DIR="$HOME/cache.tmp"

pip install pyserial

echo "OS: $OS_NAME.$ARCHIVE_FORMAT"

if [ "$OS_IS_LINUX" == "1" ]; then
	wget -O "arduino.$ARCHIVE_FORMAT" "https://www.arduino.cc/download.php?f=/arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT" > /dev/null
	tar xf "arduino.$ARCHIVE_FORMAT" > /dev/null
	mv arduino-nightly "$ARDUINO_IDE_PATH"
else
	curl -o "arduino.$ARCHIVE_FORMAT" -L "https://www.arduino.cc/download.php?f=/arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT" > /dev/null
	unzip "arduino.$ARCHIVE_FORMAT" > /dev/null
	if [ "$OS_IS_MACOS" == "1" ]; then
		mv "Arduino.app" "$HOME/Arduino.app"
	else
		mv arduino-nightly "$ARDUINO_IDE_PATH"
	fi
fi

mkdir -p "$ARDUINO_USR_PATH/libraries"
mkdir -p "$ARDUINO_USR_PATH/hardware"

function build_sketch(){ # build_sketch <fqbn> <path-to-ino>
	$ARDUINO_IDE_PATH/arduino-builder -compile -logger=human -core-api-version=10810 \
		-fqbn=$1 \
		-warnings="all" \
		-tools "$ARDUINO_IDE_PATH/tools-builder" \
		-built-in-libraries "$ARDUINO_IDE_PATH/libraries" \
		-hardware "$ARDUINO_USR_PATH/hardware" \
		-libraries "$ARDUINO_USR_PATH/libraries" \
		-build-cache "$ARDUINO_CACHE_DIR" \
		-build-path "$ARDUINO_BUILD_DIR" \
		$2
}

mkdir -p "$ARDUINO_USR_PATH/hardware/espressif"
cd "$ARDUINO_USR_PATH/hardware/espressif"
git clone https://github.com/espressif/arduino-esp32.git esp32
cd esp32
git submodule update --init --recursive
cd tools
if [ "$OS_IS_WINDOWS" == "1" ]; then
	pip install requests
fi
python get.py > /dev/null
cd $GITHUB_WORKSPACE

mkdir -p "$ARDUINO_BUILD_DIR"
mkdir -p "$ARDUINO_CACHE_DIR"
build_sketch "espressif:esp32:esp32" "$ARDUINO_USR_PATH/hardware/espressif/esp32/libraries/ESP32/examples/AnalogOut/ledcWrite_RGB/ledcWrite_RGB.ino"
