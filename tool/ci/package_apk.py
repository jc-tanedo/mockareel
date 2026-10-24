"""Verify a built APK and stage only distributable files for Actions artifacts."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from release_metadata import version

mode = sys.argv[1]
if mode not in ('debug', 'release'):
    raise SystemExit('Expected debug or release.')
name, code = version()
sdk = Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ['ANDROID_HOME'])
build_tools = sdk / 'build-tools' / '36.0.0'
apk = Path(f'build/app/outputs/flutter-apk/app-{mode}.apk')
with zipfile.ZipFile(apk) as archive:
    if archive.testzip() is not None:
        raise SystemExit('APK archive integrity check failed.')
subprocess.run([str(build_tools / 'apksigner'), 'verify', str(apk)], check=True)
subprocess.run([str(build_tools / 'zipalign'), '-c', '-P', '16', '4', str(apk)], check=True)
badging = subprocess.check_output([str(build_tools / 'aapt'), 'dump', 'badging', str(apk)], text=True).splitlines()[0]
expected_name = name + ('-debug' if mode == 'debug' else '')
expected_id = 'dev.mockareel.mockareel' + ('.debug' if mode == 'debug' else '')
if any(expected not in badging for expected in (f"name='{expected_id}'", f"versionName='{expected_name}'", f"versionCode='{code}'")):
    raise SystemExit('APK package or version does not match the source configuration.')
dist = Path('dist')
dist.mkdir(exist_ok=True)
target = dist / f'mockareel-{name}-{mode}.apk'
shutil.copyfile(apk, target)
checksum = hashlib.sha256(target.read_bytes()).hexdigest()
target.with_suffix('.apk.sha256').write_text(f'{checksum}  {target.name}\n')
print(f'Verified {target.name}; SHA-256 {checksum}')
