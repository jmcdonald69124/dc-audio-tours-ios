#!/usr/bin/env bash
# Boots an iPhone simulator, installs the Debug build, opens the app on several screens (via DEBUG launch
# arguments handled in AppModel) and saves screenshots. Used by CI; also handy locally:
#   scripts/ci-screenshots.sh build/Build/Products/Debug-iphonesimulator/DCAudioTours.app screenshots
set -euo pipefail
APP="${1:?path to DCAudioTours.app}"
OUT="${2:-screenshots}"
BID="com.fettink.dcaudiotours"
mkdir -p "$OUT"

# Newest iOS runtime's "iPhone … Pro" (falls back to any iPhone).
read -r UDID NAME < <(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
cands = []
for runtime, devs in data.items():
    if "iOS" not in runtime: continue
    for d in devs:
        if d.get("isAvailable") and d["name"].startswith("iPhone"):
            score = ("Pro" in d["name"] and "Max" not in d["name"], runtime)
            cands.append((score, d["udid"], d["name"].replace(" ", "_")))
cands.sort()
print(cands[-1][1], cands[-1][2]) if cands else print("", "")')
[ -n "$UDID" ] || { echo "no iPhone simulator available"; exit 1; }
echo "Using simulator: $NAME ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant location "$BID" || true
xcrun simctl location "$UDID" set 38.8893,-77.0502 || true     # Lincoln Memorial

shot() {   # shot <name> <light|dark> [launch args…]
  local name="$1" appearance="$2"; shift 2
  xcrun simctl ui "$UDID" appearance "$appearance"
  xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BID" "$@" >/dev/null
  sleep "${WAIT:-10}"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "  $name"
}

shot home-light      light
shot home-dark       dark
shot list-light      light -scroll-selector
shot list-dark       dark  -scroll-selector
shot tour-light      light -open-tour museums-monuments
shot tour-dark       dark  -open-tour museums-monuments
shot stop-light      light -open-stop museums-monuments/american-history
shot stop-dark       dark  -open-stop museums-monuments/american-history
shot area-light      light -open-tour area-national-mall
shot locked-light    light -open-stop oddities/einstein-memorial
shot nearby-light    light -tab nearby
shot more-light      light -tab settings
shot spanish-home    light -lang es
ls -la "$OUT"
