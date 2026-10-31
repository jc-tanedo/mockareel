"""Restore the stable CI debug signer without relying on Android's user-home paths."""
import base64
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def restore(environment):
    encoded = environment.get('DEBUG_KEYSTORE_BASE64', '')
    if not encoded.strip():
        raise ValueError('Set repository secret ANDROID_DEBUG_KEYSTORE_BASE64 before publishing debug APKs. A new runner-generated key cannot update an existing installation.')
    try:
        data = base64.b64decode(''.join(encoded.split()), validate=True)
    except ValueError:
        raise ValueError('ANDROID_DEBUG_KEYSTORE_BASE64 must contain a base64-encoded Android debug keystore.') from None
    directory = Path(tempfile.mkdtemp(prefix='mockareel-debug-signing-', dir=environment['RUNNER_TEMP']))
    path = directory / 'debug.keystore'
    try:
        path.write_bytes(data)
        path.chmod(0o600)
        try:
            certificate = subprocess.run([
                'keytool', '-exportcert', '-keystore', str(path),
                '-storepass', 'android', '-alias', 'androiddebugkey',
            ], check=True, capture_output=True).stdout
        except subprocess.CalledProcessError:
            raise ValueError('Debug keystore must have alias androiddebugkey and store password android.') from None
        fingerprint = hashlib.sha256(certificate).hexdigest()
        with open(environment['GITHUB_ENV'], 'a') as output:
            output.write(f'MOCKAREEL_DEBUG_KEYSTORE_PATH={path}\nMOCKAREEL_DEBUG_CERT_SHA256={fingerprint}\n')
        return path, fingerprint
    except BaseException:
        shutil.rmtree(directory)
        raise


def verify_signer(output, expected):
    fingerprints = re.findall(r'^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)\s*$', output, re.MULTILINE)
    if [f.lower() for f in fingerprints] != [expected.lower()]:
        raise ValueError('Debug APK signing certificate does not match the configured stable key.')


if __name__ == '__main__':
    try:
        _, fingerprint = restore(os.environ)
        print(f'Stable debug signer SHA-256: {fingerprint}')
    except (ValueError, OSError) as error:
        raise SystemExit(str(error))
