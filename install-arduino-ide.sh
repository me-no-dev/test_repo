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

ARDUINO_BUILD_DIR="$HOME/.arduino/build.tmp"
ARDUINO_CACHE_DIR="$HOME/.arduino/cache.tmp"

if [ "$OS_IS_MACOS" == "1" ]; then
	export ARDUINO_IDE_PATH="/Applications/Arduino.app/Contents/Java"
	export ARDUINO_USR_PATH="$HOME/Documents/Arduino"
else
	export ARDUINO_IDE_PATH="$HOME/arduino_ide"
	export ARDUINO_USR_PATH="$HOME/Arduino"
fi

echo "Installing Arduino IDE on $OS_NAME..."

if [ ! -d "$ARDUINO_IDE_PATH" ]; then
	echo "Downloading 'arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT' to 'arduino.$ARCHIVE_FORMAT'..."
	if [ "$OS_IS_LINUX" == "1" ]; then
		wget -O "arduino.$ARCHIVE_FORMAT" "https://www.arduino.cc/download.php?f=/arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT" > /dev/null 2>&1
		if [ $? -ne 0 ]; then echo "ERROR: Download failed"; exit 1; fi
		echo "Extracting 'arduino.$ARCHIVE_FORMAT'..."
		tar xf "arduino.$ARCHIVE_FORMAT" > /dev/null
		if [ $? -ne 0 ]; then exit 1; fi
		mv arduino-nightly "$ARDUINO_IDE_PATH"
	else
		curl -o "arduino.$ARCHIVE_FORMAT" -L "https://www.arduino.cc/download.php?f=/arduino-nightly-$OS_NAME.$ARCHIVE_FORMAT" > /dev/null 2>&1
		if [ $? -ne 0 ]; then echo "ERROR: Download failed"; exit 1; fi
		echo "Extracting 'arduino.$ARCHIVE_FORMAT'..."
		unzip "arduino.$ARCHIVE_FORMAT" > /dev/null
		if [ $? -ne 0 ]; then exit 1; fi
		if [ "$OS_IS_MACOS" == "1" ]; then
			mv "Arduino.app" "$HOME/Arduino.app"
		else
			mv arduino-nightly "$ARDUINO_IDE_PATH"
		fi
	fi
	if [ $? -ne 0 ]; then exit 1; fi
	rm -rf "arduino.$ARCHIVE_FORMAT"
fi

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

	echo ""
	echo "Compiling '"$(basename "$sketch")"'..."
	mkdir -p "$ARDUINO_BUILD_DIR"
	mkdir -p "$ARDUINO_CACHE_DIR"
	$ARDUINO_IDE_PATH/arduino-builder -compile -logger=human -core-api-version=10810 \
		-fqbn=$fqbn \
		-warnings="none" \
		-tools "$ARDUINO_IDE_PATH/tools-builder" \
		-tools "$ARDUINO_IDE_PATH/tools" \
		-built-in-libraries "$ARDUINO_IDE_PATH/libraries" \
		-hardware "$ARDUINO_IDE_PATH/hardware" \
		-hardware "$ARDUINO_USR_PATH/hardware" \
		-libraries "$ARDUINO_USR_PATH/libraries" \
		-build-cache "$ARDUINO_CACHE_DIR" \
		-build-path "$ARDUINO_BUILD_DIR" \
		$win_opts $xtra_opts "$sketch"
}

function count_sketches() # count_sketches <examples-path>
{
	local examples="$1"
    local sketches=$(find $examples -name *.ino)
    local sketchnum=0
    rm -rf sketches.txt
    for sketch in $sketches; do
        local sketchdir=$(dirname $sketch)
        local sketchdirname=$(basename $sketchdir)
        local sketchname=$(basename $sketch)
        if [[ "${sketchdirname}.ino" != "$sketchname" ]]; then
            continue
        fi;
        if [[ -f "$sketchdir/.test.skip" ]]; then
            continue
        fi
        echo $sketch >> sketches.txt
        sketchnum=$(($sketchnum + 1))
    done
    return $sketchnum
}

function build_sketches() # build_sketches <examples-path> <fqbn> <chunk> <total-chunks> [extra-options]
{
    local examples=$1
    local fqbn=$2
    local chunk_idex=$3
    local chunks_num=$4
    local xtra_opts=$5

	if [ "$chunks_num" -le 0 ]; then
		echo "ERROR: Chunks count must be positive number"
		return 1
	fi
	if [ "$chunk_idex" -ge "$chunks_num" ]; then
		echo "ERROR: Chunk index must be less than chunks count"
		return 1
	fi

    count_sketches "$examples"
    local sketchcount=$?
    local sketches=$(cat sketches.txt)

    local chunk_size=$(( $sketchcount / $chunks_num ))
    local all_chunks=$(( $chunks_num * $chunk_size ))
    if [ "$all_chunks" -lt "$sketchcount" ]; then
    	chunk_size=$(( $chunk_size + 1 ))
    fi

    local start_index=$(( $chunk_idex * $chunk_size ))
    if [ "$sketchcount" -le "$start_index" ]; then
    	echo "Skipping job"
    	return 0
    fi

    local end_index=$(( $(( $chunk_idex + 1 )) * $chunk_size ))
    if [ "$end_index" -gt "$sketchcount" ]; then
    	end_index=$sketchcount
    fi

    local start_num=$(( $start_index + 1 ))
    echo "Found $sketchcount Sketches";
    echo "Chunk Count : $chunks_num"
    echo "Chunk Size  : $chunk_size"
    echo "Start Sketch: $start_num"
    echo "End Sketch  : $end_index"

    local sketchnum=0
    for sketch in $sketches; do
        local sketchdir=$(dirname $sketch)
        local sketchdirname=$(basename $sketchdir)
        local sketchname=$(basename $sketch)
        if [[ "${sketchdirname}.ino" != "$sketchname" ]]; then
            #echo "Skipping $sketch, beacause it is not the main sketch file";
            continue
        fi;
        if [[ -f "$sketchdir/.test.skip" ]]; then
            #echo "Skipping $sketch marked";
            continue
        fi
        sketchnum=$(($sketchnum + 1))
        if [ "$sketchnum" -le "$start_index" ]; then
        	#echo "Skipping $sketch index low"
        	continue
        fi
        if [ "$sketchnum" -gt "$end_index" ]; then
        	#echo "Skipping $sketch index high"
        	continue
        fi
        build_sketch "$fqbn" "$sketch" "$xtra_opts"
        local result=$?
        if [ $result -ne 0 ]; then
            return $result
        fi
    done
    return 0
}

echo "Arduino IDE Installed in '$ARDUINO_IDE_PATH'"
# echo "You can install boards in '$ARDUINO_IDE_PATH/hardware' or in '$ARDUINO_USR_PATH/hardware'"
# echo "User libraries should be installed in '$ARDUINO_USR_PATH/libraries'"
# echo "Then you can call 'build_sketch <fqbn> <path-to-ino> [extra-options]' to build your sketches"
echo ""

