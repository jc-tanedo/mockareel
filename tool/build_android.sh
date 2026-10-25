#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tool/cloud_env.sh
# Keep build-time configuration outside the checkout and never echo key values.
mockareel_defines="$(mktemp /tmp/mockareel-defines.XXXXXX)"
trap 'rm -f "$mockareel_defines"' EXIT
python3 - "$mockareel_defines" <<'PY'
import json, os, re, sys
key = os.environ.get('MAPS_API_KEY', '')
# Secret proxies can provide placeholders that cannot authenticate on a phone.
if key and not re.fullmatch(r'AIza[0-9A-Za-z_-]{35}', key):
    print('MAPS_API_KEY is not a client API key; the APK will use its on-device key setting.')
    key = ''
with open(sys.argv[1], 'w') as f:
    json.dump({'MAPS_API_KEY': key}, f)
print('Building with Places search configured.' if key else 'No build-time Maps key is available. Browser lookup and map capture work without one; optional API access is in Advanced settings.')
PY
flutter build apk --release --dart-define-from-file="$mockareel_defines" "$@"
