#!/bin/bash
# Runs Keystone on the iPhone 17 Pro Max simulator, stdin on a FIFO:
#   echo r > /tmp/keystone/fifo   hot reload     (R restart, q quit)
# The FIFO lives outside the project: a pipe inside it hangs `flutter build`.
# Extra arguments go to `flutter run` (for example --dart-define=startTab=shop).
cd "$(dirname "$0")/.."
mkdir -p /tmp/keystone
rm -f /tmp/keystone/fifo
mkfifo /tmp/keystone/fifo
sleep 100000 > /tmp/keystone/fifo &
HOLD=$!
trap 'kill $HOLD 2>/dev/null' EXIT
flutter run -d "${KEYSTONE_DEVICE:-44CDDB86-D61F-47C8-8C65-7C87828A38C5}" "$@" < /tmp/keystone/fifo > /tmp/keystone/run.log 2>&1
