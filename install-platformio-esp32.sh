#!/bin/bash

echo "Installing Python Wheel..."
pip install wheel > /dev/null 2>&1
if [ $? -ne 0 ]; then echo "ERROR: Install failed"; exit 1; fi

echo "Installing PlatformIO..."
pip install -U https://github.com/platformio/platformio/archive/develop.zip > /dev/null 2>&1
if [ $? -ne 0 ]; then echo "ERROR: Install failed"; exit 1; fi

echo "Installing Platform ESP32..."
python -m platformio platform install https://github.com/platformio/platform-espressif32.git#feature/stage > /dev/null 2>&1
if [ $? -ne 0 ]; then echo "ERROR: Install failed"; exit 1; fi

echo "Replacing the framework version..."
if [[ "$OSTYPE" == "darwin"* ]]; then
	sed 's/https:\/\/github\.com\/espressif\/arduino-esp32\.git/*/' "$HOME/.platformio/platforms/espressif32/platform.json" > "platform.json" && \
	mv -f "platform.json" "$HOME/.platformio/platforms/espressif32/platform.json"
else
	sed -i 's/https:\/\/github\.com\/espressif\/arduino-esp32\.git/*/' "$HOME/.platformio/platforms/espressif32/platform.json"
fi
if [ $? -ne 0 ]; then echo "ERROR: Replace failed"; exit 1; fi

if [ "$GITHUB_REPOSITORY" == "espressif/arduino-esp32" ];  then
	echo "Linking Core..." && \
	ln -s $GITHUB_WORKSPACE "$HOME/.platformio/packages/framework-arduinoespressif32"
else
	echo "Cloning Core Repository..." && \
	git clone https://github.com/espressif/arduino-esp32.git "$HOME/.platformio/packages/framework-arduinoespressif32" > /dev/null 2>&1
	if [ $? -ne 0 ]; then echo "ERROR: GIT clone failed"; exit 1; fi
fi

echo "PlatformIO for ESP32 has been installed"
echo ""


function build_pio_sketch(){ # build_pio_sketch <board> <path-to-ino> [extra-options]
	local board="$1"
	local sketch="$2"
	local xtra_opts=$3
	local sketch_dir=$(dirname "$sketch")
	echo ""
	echo "Compiling '"$(basename "$sketch")"'..."
	python -m platformio ci  --board "$board" "$sketch_dir" $xtra_opts
}

build_pio_sketch "esp32dev" "$HOME/.platformio/packages/framework-arduinoespressif32/libraries/ESP32/examples/AnalogOut/ledcWrite_RGB/ledcWrite_RGB.ino" --project-option="board_build.partitions = huge_app.csv"