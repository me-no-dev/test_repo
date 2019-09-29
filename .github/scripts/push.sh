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

if [ -x $CHUNK_INDEX ] ||  [ -x $CHUNKS_CNT ]; then
    echo "Chunk index and/or count are not defined"
    exit 1
fi

#source "$GITHUB_WORKSPACE/install-arduino-ide.sh"
#source "$GITHUB_WORKSPACE/install-arduino-core-esp32.sh"
#source "$GITHUB_WORKSPACE/install-arduino-core-esp8266.sh"

#build_sketch "espressif:esp32:esp32" "$ARDUINO_USR_PATH/hardware/espressif/esp32/libraries/ESP32/examples/AnalogOut/ledcWrite_RGB/ledcWrite_RGB.ino"
#build_sketches "$ARDUINO_USR_PATH/hardware/espressif/esp32/libraries" "espressif:esp32:esp32:PSRAM=enabled,PartitionScheme=huge_app" "$CHUNK_INDEX" "$CHUNKS_CNT"
#build_sketches "$ARDUINO_USR_PATH/hardware/esp8266com/esp8266/libraries" "esp8266com:esp8266:generic:eesz=4M1M,ip=lm2f" "$CHUNK_INDEX" "$CHUNKS_CNT"

source "$GITHUB_WORKSPACE/install-platformio-esp32.sh"
#build_pio_sketch "esp32dev" "$HOME/.platformio/packages/framework-arduinoespressif32/libraries/ESP32/examples/Camera/CameraWebServer/CameraWebServer.ino"
build_pio_sketches "$HOME/.platformio/packages/framework-arduinoespressif32/libraries" "esp32dev" "$CHUNK_INDEX" "$CHUNKS_CNT"

if [ $? -ne 0 ]; then exit 1; fi
