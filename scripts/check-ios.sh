#!/usr/bin/env bash
set -euo pipefail
command -v xcodegen >/dev/null || brew install xcodegen
python3 scripts/make_icon.py
xcodegen generate
xcodebuild -version
xcodegen --version
xcrun simctl list devices available -j > /tmp/unifi-simulators.json
DEVICE_ID=$(python3 - <<'PYCODE'
import json
with open('/tmp/unifi-simulators.json') as f:
    devices = json.load(f)['devices']
for runtime, entries in sorted(devices.items(), reverse=True):
    if 'iOS' not in runtime:
        continue
    for device in entries:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            print(device['udid'])
            raise SystemExit(0)
raise SystemExit('No available iPhone simulator')
PYCODE
)
xcodebuild test -project Unifi.xcodeproj -scheme Unifi \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath build/DerivedData -resultBundlePath build/Tests.xcresult \
  CODE_SIGNING_ALLOWED=NO
