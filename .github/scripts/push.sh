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
  		export OS_IS_LINUX="1"
  		export ARCHIVE_FORMAT="tar.xz"
        if [[ "$OSBITS" == "i686" ]]; then
        	echo "linux32"
        elif [[ "$OSBITS" == "x86_64" ]]; then
        	echo "linux64"
        elif [[ "$OSBITS" == "armv7l" ]]; then
        	echo "linuxarm"
        else
        	echo "$OSTYPE-$OSBITS"
	    	return 1
        fi
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		export OS_IS_MACOS="1"
  		export ARCHIVE_FORMAT="zip"
	    echo "macosx"
	elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
		export OS_IS_WINDOWS="1"
  		export ARCHIVE_FORMAT="zip"
	    echo "windows"
	else
	    echo "$OSTYPE-$OSBITS"
	    return 1
	fi
	return 0
}

OS_NAME=`get_os`
echo "OS: $OS_NAME"

#OSTYPE: 'linux-gnu', ARCH: 'x86_64' => linux64
#OSTYPE: 'msys', ARCH: 'x86_64' => win32
#OSTYPE: 'darwin18', ARCH: 'i386' => macos

ARDUINO_IDE_PATH="$HOME/arduino_ide"
ARDUINO_USR_PATH="$HOME/Arduino"
ARDUINO_BUILD_DIR="$HOME/build.tmp"
ARDUINO_CACHE_DIR="$HOME/cache.tmp"
ARDUINO_BUILD_CMD="$ARDUINO_IDE_PATH/arduino-builder -compile -logger=human -core-api-version=10810 -hardware \"$ARDUINO_USR_PATH/hardware\" -tools \"$ARDUINO_IDE_PATH/tools-builder\" -built-in-libraries \"$ARDUINO_IDE_PATH/libraries\" -libraries \"$ARDUINO_USR_PATH/libraries\" -fqbn=$PLATFORM_FQBN -warnings=\"all\" -build-cache \"$ARDUINO_CACHE_DIR\" -build-path \"$ARDUINO_BUILD_DIR\" -verbose"

pip install pyserial
curl "https://www.arduino.cc/download.php?f=/arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT" --output "arduino.$ARCHIVE_FORMAT"
if [ -n $OS_IS_LINUX ]; then
	tar xf arduino.tar.xz
else
	unzip arduino.zip
fi
mv arduino-nightly "$ARDUINO_IDE_PATH"
mkdir -p "$ARDUINO_USR_PATH/libraries"
mkdir -p "$ARDUINO_USR_PATH/hardware"

mkdir -p "$ARDUINO_USR_PATH/hardware/espressif"
cd "$ARDUINO_USR_PATH/hardware/espressif"
git clone https://github.com/espressif/arduino-esp32.git esp32
cd esp32
git submodule update --init --recursive
cd tools
python get.py
PLATFORM_FQBN="espressif:esp32:esp32"

cd $GITHUB_WORKSPACE

$ARDUINO_BUILD_CMD "$ARDUINO_USR_PATH/hardware/espressif/libraries/ESP32/examples/AnalogOut/ledcWrite_RGB/ledcWrite_RGB.ino"
