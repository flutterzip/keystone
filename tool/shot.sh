#!/bin/bash
# Screenshot of the simulator, scaled:  tool/shot.sh out.png [height]
xcrun simctl io "${KEYSTONE_DEVICE:-44CDDB86-D61F-47C8-8C65-7C87828A38C5}" screenshot "$1" >/dev/null 2>&1
sips -Z "${2:-900}" "$1" >/dev/null
