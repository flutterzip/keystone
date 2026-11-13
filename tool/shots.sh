#!/bin/bash
# Takes the README screenshots on the simulator: real shaders, a 9:41 status
# bar, light and dark. Builds a debug simulator app once, then relaunches it
# into each state through LaunchHooks (lib/config/launch_hooks.dart).
#   tool/shots.sh            all screens into docs/screens/
set -e
cd "$(dirname "$0")/.."
D="${KEYSTONE_DEVICE:-44CDDB86-D61F-47C8-8C65-7C87828A38C5}"
ID=com.flutterzip.keystone
OUT="$PWD/docs/screens"   # absolute: simctl does not resolve relative paths
mkdir -p "$OUT"
flutter build ios --simulator --debug >/dev/null
xcrun simctl install "$D" build/ios/iphonesimulator/Runner.app
xcrun simctl status_bar "$D" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
DOCS="$(xcrun simctl get_app_container "$D" "$ID" data)/Documents"
mkdir -p "$DOCS"
shot() { # name, state, seconds to wait
  xcrun simctl terminate "$D" "$ID" >/dev/null 2>&1 || true
  printf '%s' "$2" > "$DOCS/launch_start.txt"
  xcrun simctl launch "$D" "$ID" >/dev/null
  sleep "${3:-8}"
  xcrun simctl io "$D" screenshot "$OUT/$1.png" >/dev/null 2>&1
  sips -Z 1300 "$OUT/$1.png" >/dev/null
}
shot onboarding   "fresh,light" 9
shot sign-in      "fresh,light,touch=300/400x92" 10
shot home         "fresh,signedIn,light"
shot property     "fresh,signedIn,light,open=home:belem"
shot search-map   "fresh,signedIn,light,open=map,touch=1500/226x560" 10
shot booking      "fresh,signedIn,light,open=book:alfama,touch=1500/232x226/600/120x400" 11
shot viewings     "fresh,signedIn,light,tab=viewings"
shot saved        "fresh,signedIn,light,tab=saved"
shot messages     "fresh,signedIn,light,open=thread:t-ines"
shot application  "fresh,signedIn,light,open=application:chiado"
shot brochure     "fresh,signedIn,light,open=brochure:jacaranda"
shot profile      "fresh,signedIn,light,tab=profile" 9
shot home-dark    "fresh,signedIn,dark,kind=sale"
shot property-dark "fresh,signedIn,dark,open=home:jacaranda"
shot profile-dark "fresh,signedIn,dark,tab=profile" 9
xcrun simctl terminate "$D" "$ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$D" clear
echo "screens written to $OUT"
