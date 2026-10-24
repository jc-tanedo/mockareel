#!/usr/bin/env bash
# Portable build entry point: uses the toolchain already on PATH (local or CI).
set -euo pipefail
cd "$(dirname "$0")/../.."
mockareel_mode="${1:-debug}"
case "$mockareel_mode" in debug|release) ;; *) echo 'Usage: build_apk.sh debug|release' >&2; exit 2 ;; esac
mockareel_defines="$(mktemp)"
trap 'rm -f "$mockareel_defines"' EXIT
python3 - "$mockareel_defines" <<'PY'
import json, os, re, sys
key = os.environ.get('MAPS_API_KEY', '')
if key and not re.fullmatch(r'AIza[0-9A-Za-z_-]{35}', key):
    raise SystemExit('MAPS_API_KEY must be a client API key, or omitted to use on-device Settings.')
with open(sys.argv[1], 'w') as output:
    json.dump({'MAPS_API_KEY': key}, output)
PY
# Flutter must regenerate the plugin registrant for this build mode. Tests/pub
# get include integration_test; release builds exclude that dev-only plugin.
# --no-pub also skips that regeneration and leaves uncompilable Java behind.
flutter build apk "--$mockareel_mode" --pub --dart-define-from-file="$mockareel_defines"
python3 tool/ci/package_apk.py "$mockareel_mode"
