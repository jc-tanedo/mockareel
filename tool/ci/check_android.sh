#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# Sequential: Flutter tests and Android builds share generated plugin registration.
python3 -m unittest discover -s tool/ci -p 'test_*.py'
if ! dart format --output=none --set-exit-if-changed lib test integration_test tool; then
  echo "::error::dart format found formatting differences:"
  dart format lib test integration_test tool
  git diff --stat
  git diff
  exit 1
fi
flutter analyze --no-pub
flutter test --no-pub
bash android/gradlew -p android :app:testDebugUnitTest --max-workers=2
