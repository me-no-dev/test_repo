#!/bin/bash

echo "Installing ESP32 Arduino in '$ARDUINO_USR_PATH/hardware/espressif'..."

mkdir -p "$ARDUINO_USR_PATH/hardware/espressif" && \
cd "$ARDUINO_USR_PATH/hardware/espressif" && \
echo "Installing Core..." && \
git clone https://github.com/espressif/arduino-esp32.git esp32 > /dev/null && \
cd esp32 && \
echo "Updating submodules..." && \
git submodule update --init --recursive > /dev/null && \
cd tools
if [ "$OS_IS_WINDOWS" == "1" ]; then
	echo "Installing Python Requests..."
	pip install requests > /dev/null
fi
echo "Downloading the tools and the toolchain..."
python get.py > /dev/null
cd $GITHUB_WORKSPACE

echo "ESP32 Arduino has been installed in '$ARDUINO_USR_PATH/hardware/espressif'"
