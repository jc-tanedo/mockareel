"""Validate the release tag before signing, building or publishing anything."""
import os
from pathlib import Path
import re
import subprocess


def version():
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\+(\d+)\s*$', Path('pubspec.yaml').read_text(), re.M)
    if not match:
        raise SystemExit('pubspec.yaml must declare version: X.Y.Z+BUILD (or X.Y.Z-prerelease+BUILD).')
    return match.group(1), int(match.group(2))


def main():
    name, code = version()
    tag = os.environ.get('RELEASE_TAG', '')
    if tag != f'v{name}' or code < 1:
        raise SystemExit('Release tag must be v<pubspec version>, with a positive build number.')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    target = subprocess.check_output(['git', 'rev-parse', '--verify', f'refs/tags/{tag}^{{commit}}'], text=True).strip()
    if commit != target:
        raise SystemExit('The checkout must match the selected version tag.')
    values = {'tag': tag, 'version': name, 'prerelease': str('-' in name).lower(), 'commit': commit}
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            for key, value in values.items():
                output.write(f'{key}={value}\n')
    print(f'Validated {tag}, Android build {code}, commit {commit}.')


if __name__ == '__main__':
    main()
