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

CHUNK_INDEX=$1
CHUNKS_CNT=$2
BUILD_PIO=0
if [ "$#" -lt 2 ] ||  [ "$CHUNKS_CNT" -le 0 ]; then
	echo "Building all sketches"
	CHUNK_INDEX=0
	CHUNKS_CNT=1
fi
if [ "$CHUNK_INDEX" -gt "$CHUNKS_CNT" ]; then
	CHUNK_INDEX=$CHUNKS_CNT
fi
if [ "$CHUNK_INDEX" -eq "$CHUNKS_CNT" ]; then
	BUILD_PIO=1
fi

# CMake Test
if [ "$CHUNK_INDEX" -eq 0 ]; then
	bash ./tools/ci/check-cmakelists.sh
	if [ $? -ne 0 ]; then exit 1; fi
fi

if [ "$BUILD_PIO" -eq 0 ]; then
	# ArduinoIDE Test
	FQBN="espressif:esp32:esp32:PSRAM=enabled,PartitionScheme=huge_app"
	source ./tools/ci/install-arduino-ide.sh
	source ./tools/ci/install-arduino-core-esp32.sh
	if [ "$OS_IS_WINDOWS" == "1" ]; then
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/WiFiClientSecure/examples/WiFiClientSecure/WiFiClientSecure.ino" && \
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/BLE/examples/BLE_server/BLE_server.ino" && \
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/AzureIoT/examples/GetStarted/GetStarted.ino" && \
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/ESP32/examples/Camera/CameraWebServer/CameraWebServer.ino"
	elif [ "$OS_IS_MACOS" == "1" ]; then
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/WiFi/examples/WiFiClient/WiFiClient.ino" && \
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/WiFiClientSecure/examples/WiFiClientSecure/WiFiClientSecure.ino" && \
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/BluetoothSerial/examples/SerialToSerialBT/SerialToSerialBT.ino" && \
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/BLE/examples/BLE_server/BLE_server.ino" && \
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/AzureIoT/examples/GetStarted/GetStarted.ino" && \
		build_sketch "$FQBN" "$ARDUINO_ESP32_PATH/libraries/ESP32/examples/Camera/CameraWebServer/CameraWebServer.ino"
	else
		build_sketches "$ARDUINO_ESP32_PATH/libraries" "$FQBN" "$CHUNK_INDEX" "$CHUNKS_CNT"
	fi
else
	# PlatformIO Test
	source ./tools/ci/install-platformio-esp32.sh
	BOARD="esp32dev"
	build_pio_sketch "$BOARD" "$PLATFORMIO_ESP32_PATH/libraries/WiFi/examples/WiFiClient/WiFiClient.ino" && \
	build_pio_sketch "$BOARD" "$PLATFORMIO_ESP32_PATH/libraries/WiFiClientSecure/examples/WiFiClientSecure/WiFiClientSecure.ino" && \
	build_pio_sketch "$BOARD" "$PLATFORMIO_ESP32_PATH/libraries/BluetoothSerial/examples/SerialToSerialBT/SerialToSerialBT.ino" && \
	build_pio_sketch "$BOARD" "$PLATFORMIO_ESP32_PATH/libraries/BLE/examples/BLE_server/BLE_server.ino" && \
	build_pio_sketch "$BOARD" "$PLATFORMIO_ESP32_PATH/libraries/AzureIoT/examples/GetStarted/GetStarted.ino" && \
	build_pio_sketch "$BOARD" "$PLATFORMIO_ESP32_PATH/libraries/ESP32/examples/Camera/CameraWebServer/CameraWebServer.ino"
	#build_pio_sketches libraries esp32dev $CHUNK_INDEX $CHUNKS_CNT
fi
if [ $? -ne 0 ]; then exit 1; fi
