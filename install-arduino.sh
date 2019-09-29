#!/bin/bash

#OSTYPE: 'linux-gnu', ARCH: 'x86_64' => linux64
#OSTYPE: 'msys', ARCH: 'x86_64' => win32
#OSTYPE: 'darwin18', ARCH: 'i386' => macos

OSBITS=`arch`
if [[ "$OSTYPE" == "linux"* ]]; then
	export OS_IS_LINUX="1"
	ARCHIVE_FORMAT="tar.xz"
	if [[ "$OSBITS" == "i686" ]]; then
		OS_NAME="linux32"
	elif [[ "$OSBITS" == "x86_64" ]]; then
		OS_NAME="linux64"
	elif [[ "$OSBITS" == "armv7l" ]]; then
		OS_NAME="linuxarm"
	else
		OS_NAME="$OSTYPE-$OSBITS"
		echo "Unknown OS '$OS_NAME'"
		exit 1
	fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
	export OS_IS_MACOS="1"
	ARCHIVE_FORMAT="zip"
	OS_NAME="macosx"
elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
	export OS_IS_WINDOWS="1"
	ARCHIVE_FORMAT="zip"
	OS_NAME="windows"
else
	OS_NAME="$OSTYPE-$OSBITS"
	echo "Unknown OS '$OS_NAME'"
	exit 1
fi
export OS_NAME

export ARDUINO_USR_PATH="$HOME/Arduino"
ARDUINO_BUILD_DIR="$HOME/build.tmp"
ARDUINO_CACHE_DIR="$HOME/cache.tmp"

if [ "$OS_IS_MACOS" == "1" ]; then
	export ARDUINO_IDE_PATH="$HOME/Arduino.app/Contents/Java"
else
	export ARDUINO_IDE_PATH="$HOME/arduino_ide"
fi

echo "Installing Arduino IDE on $OS_NAME..."

echo "Downloading 'arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT' to 'arduino.$ARCHIVE_FORMAT'..."
if [ "$OS_IS_LINUX" == "1" ]; then
	wget -O "arduino.$ARCHIVE_FORMAT" "https://www.arduino.cc/download.php?f=/arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT" > /dev/null 2>&1
	echo "Extracting 'arduino.$ARCHIVE_FORMAT'..."
	tar xf "arduino.$ARCHIVE_FORMAT" > /dev/null
	mv arduino-nightly "$ARDUINO_IDE_PATH"
else
	curl -o "arduino.$ARCHIVE_FORMAT" -L "https://www.arduino.cc/download.php?f=/arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT" > /dev/null 2>&1
	echo "Extracting 'arduino.$ARCHIVE_FORMAT'..."
	unzip "arduino.$ARCHIVE_FORMAT" > /dev/null
	if [ "$OS_IS_MACOS" == "1" ]; then
		mv "Arduino.app" "$HOME/Arduino.app"
	else
		mv arduino-nightly "$ARDUINO_IDE_PATH"
	fi
fi
rm -rf "arduino.$ARCHIVE_FORMAT"

mkdir -p "$ARDUINO_USR_PATH/libraries"
mkdir -p "$ARDUINO_USR_PATH/hardware"

function build_sketch(){ # build_sketch <fqbn> <path-to-ino> [extra-options]
	local fqbn="$1"
	local sketch="$2"
	local xtra_opts="$3"
	local win_opts=""
	if [ "$OS_IS_WINDOWS" == "1" ]; then
		local ctags_version=`ls "$ARDUINO_IDE_PATH/tools-builder/ctags/"`
		local preprocessor_version=`ls "$ARDUINO_IDE_PATH/tools-builder/arduino-preprocessor/"`
		win_opts="-prefs=runtime.tools.ctags.path=$ARDUINO_IDE_PATH/tools-builder/ctags/$ctags_version -prefs=runtime.tools.arduino-preprocessor.path=$ARDUINO_IDE_PATH/tools-builder/arduino-preprocessor/$preprocessor_version"
	fi

	echo "Compiling '"$(basename "$sketch")"'..."
	mkdir -p "$ARDUINO_BUILD_DIR"
	mkdir -p "$ARDUINO_CACHE_DIR"
	$ARDUINO_IDE_PATH/arduino-builder -compile -logger=human -core-api-version=10810 \
		-fqbn=$fqbn \
		-warnings="all" \
		-tools "$ARDUINO_IDE_PATH/tools-builder" \
		-tools "$ARDUINO_IDE_PATH/tools" \
		-built-in-libraries "$ARDUINO_IDE_PATH/libraries" \
		-hardware "$ARDUINO_IDE_PATH/hardware" \
		-hardware "$ARDUINO_USR_PATH/hardware" \
		-libraries "$ARDUINO_USR_PATH/libraries" \
		-build-cache "$ARDUINO_CACHE_DIR" \
		-build-path "$ARDUINO_BUILD_DIR" \
		$win_opts $xtra_opts "$sketch"
	echo ""
}

echo "Arduino IDE Installed in '$ARDUINO_IDE_PATH'"
# echo "You can install boards in '$ARDUINO_IDE_PATH/hardware' or in '$ARDUINO_USR_PATH/hardware'"
# echo "User libraries should be installed in '$ARDUINO_USR_PATH/libraries'"
# echo "Then you can call 'build_sketch <fqbn> <path-to-ino> [extra-options]' to build your sketches"
echo ""

