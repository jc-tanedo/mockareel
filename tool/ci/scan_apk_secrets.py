"""Scan APK contents or all reachable Git APK blobs; never print matched values.

Usage: python3 tool/ci/scan_apk_secrets.py --history
       python3 tool/ci/scan_apk_secrets.py path/to/app.apk
This complements Gitleaks: compressed APK entries are inspected explicitly.
"""
import argparse
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

RULES = {
    'google-api-key': rb'AIza[0-9A-Za-z_-]{35}',
    'github-token': rb'(?:gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{60,255})',
    'aws-access-id': rb'(?:AKIA|ASIA)[A-Z0-9]{16}',
    'private-key-marker': rb'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
    'slack-token': rb'xox[baprs]-[0-9A-Za-z-]{20,}',
    'stripe-secret': rb'(?:sk|rk)_live_[0-9A-Za-z]{20,}',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true')
    parser.add_argument('apks', nargs='*')
    args = parser.parse_args()
    if not args.history and not args.apks:
        parser.error('Provide APK paths or --history.')
    inputs = [(str(Path(path)), None) for path in args.apks]
    if args.history:
        lines = subprocess.check_output(['git', 'rev-list', '--objects', '--all'], text=True).splitlines()
        inputs += [(path, oid) for oid, path in (line.split(' ', 1) for line in lines if ' ' in line) if path.endswith('.apk')]
    findings = []
    entries = 0
    total = 0
    for path, oid in inputs:
        content = subprocess.check_output(['git', 'cat-file', 'blob', oid]) if oid else Path(path).read_bytes()
        with zipfile.ZipFile(io.BytesIO(content)) as archive:
            for entry in archive.infolist():
                if entry.is_dir():
                    continue
                value = archive.read(entry)
                entries += 1
                total += len(value)
                for rule, pattern in RULES.items():
                    if re.search(pattern, value):
                        findings.append({'apk': path, 'object': oid, 'entry': entry.filename, 'rule': rule})
    print(json.dumps({'apk_objects': len(inputs), 'archive_entries': entries, 'uncompressed_bytes': total, 'findings': findings}, indent=2))
    return bool(findings)


if __name__ == '__main__':
    sys.exit(main())
