#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# Sequential: Flutter tests and Android builds share generated plugin registration.
python3 -m unittest discover -s tool/ci -p 'test_*.py'
flutter analyze --no-pub
flutter test --no-pub
bash android/gradlew -p android :app:testDebugUnitTest --max-workers=2
