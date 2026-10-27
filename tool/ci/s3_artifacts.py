#!/usr/bin/env python3
"""Private SeaweedFS S3 build bundles; published GitHub Releases are independent."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import uuid
import zipfile

from prune_artifacts import github_api

ENDPOINT = 'https://s3.jczr.dev'
BUCKET = 'gh-artifact-store'


def client():
    import boto3
    from botocore.config import Config
    key = os.environ.get('S3_ACCESS_KEY_ID')
    secret = os.environ.get('S3_SECRET_ACCESS_KEY')
    if not key or not secret:
        raise SystemExit('Configure repository variable S3_ACCESS_KEY_ID and secret S3_SECRET_ACCESS_KEY.')
    return boto3.client(
        's3', endpoint_url=ENDPOINT, region_name='us-east-1',
        aws_access_key_id=key, aws_secret_access_key=secret,
        config=Config(signature_version='s3v4', s3={'addressing_style': 'path'},
                      request_checksum_calculation='when_required',
                      response_checksum_validation='when_required',
                      connect_timeout=15, read_timeout=120,
                      retries={'max_attempts': 3, 'mode': 'standard'}),
    )


def base(repository, kind):
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', repository) or kind not in ('debug', 'release'):
        raise ValueError('Invalid repository or build type')
    return f'{repository}/{kind}/'


def bundle_prefix(repository, kind, run_id, attempt):
    if not str(run_id).isdigit() or not str(attempt).isdigit():
        raise ValueError('Invalid run ID or attempt')
    return f'{base(repository, kind)}{run_id}-{attempt}/'


def allowed_file(name):
    return bool(re.fullmatch(r'mockareel-[\w.+-]+\.apk(?:\.sha256)?', name) or name == 'release-notes.md')


def upload(s3, prefix, directory):
    files = sorted(path for path in Path(directory).iterdir() if path.is_file() and allowed_file(path.name))
    apks = [path for path in files if path.suffix == '.apk']
    if len(apks) != 1 or not any(path.name == apks[0].name + '.sha256' for path in files):
        raise ValueError('Bundle requires exactly one APK and its checksum')
    with tempfile.TemporaryDirectory() as temporary:
        archive = Path(temporary) / 'artifact.zip'
        with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_STORED) as bundle:
            for path in files:
                bundle.write(path, path.name)
        with archive.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        s3.upload_file(str(archive), BUCKET, prefix + 'artifact.zip', ExtraArgs={'ContentType': 'application/zip'})
        # Commit marker is written last: partial uploads cannot displace good bundles.
        s3.put_object(Bucket=BUCKET, Key=prefix + 'manifest.json', ContentType='application/json',
                      Body=json.dumps({'sha256': digest, 'files': [path.name for path in files]}).encode())
    print(f'Uploaded s3://{BUCKET}/{prefix}artifact.zip')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(f'attempt={os.environ["GITHUB_RUN_ATTEMPT"]}\n')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        url = s3.generate_presigned_url('get_object', Params={
            'Bucket': BUCKET, 'Key': prefix + 'artifact.zip',
            'ResponseContentDisposition': 'attachment; filename="mockareel-artifacts.zip"',
        }, ExpiresIn=86400)
        with open(summary, 'a') as output:
            output.write(f'### Build download\n\n[Download APK and checksum]({url}) · private link valid for 24 hours.\n\n'
                         f'Permanent object: `s3://{BUCKET}/{prefix}artifact.zip` (until retention cleanup).\n')


def download(s3, prefix, directory):
    manifest = json.loads(s3.get_object(Bucket=BUCKET, Key=prefix + 'manifest.json')['Body'].read())
    with tempfile.TemporaryDirectory() as temporary:
        archive = Path(temporary) / 'artifact.zip'
        s3.download_file(BUCKET, prefix + 'artifact.zip', str(archive))
        with archive.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        if digest != manifest['sha256']:
            raise ValueError('Downloaded artifact checksum mismatch')
        with zipfile.ZipFile(archive) as bundle:
            names = bundle.namelist()
            if (len(names) != len(set(names)) or sorted(names) != sorted(manifest['files'])
                    or not all(allowed_file(name) for name in names)):
                raise ValueError('Invalid bundle filenames')
            Path(directory).mkdir(parents=True, exist_ok=True)
            bundle.extractall(directory)


def prune(s3, repository, api=github_api):
    completed = {}
    for kind in ('debug', 'release'):
        root = base(repository, kind)
        groups = {}
        for page in s3.get_paginator('list_objects_v2').paginate(Bucket=BUCKET, Prefix=root):
            for obj in page.get('Contents', []):
                relative = obj['Key'][len(root):]
                match = re.fullmatch(r'(\d+)-(\d+)/(artifact\.zip|manifest\.json)', relative)
                if not match:
                    continue
                run_id = match[1]
                if run_id not in completed:
                    run = api(f'repos/{repository}/actions/runs/{run_id}')
                    completed[run_id] = run['status'] == 'completed'
                if not completed[run_id]:
                    continue  # Publishing may still need this bundle.
                prefix = root + relative.rsplit('/', 1)[0] + '/'
                groups.setdefault(prefix, []).append(obj)
        ready = [prefix for prefix, objects in groups.items()
                 if any(obj['Key'].endswith('/manifest.json') for obj in objects)]
        ready.sort(key=lambda prefix: max(obj['LastModified'] for obj in groups[prefix]), reverse=True)
        keep = set(ready[:2])
        for prefix, objects in groups.items():
            if prefix in keep:
                continue
            # Includes incomplete uploads from finished/cancelled runs.
            for obj in objects:
                s3.delete_object(Bucket=BUCKET, Key=obj['Key'])
            print(f'Deleted s3://{BUCKET}/{prefix}')
        print(f'{kind}: retained {len(keep)} completed bundles')


def check(s3, repository):
    base(repository, "debug")  # Validate repository before constructing a storage key.
    key = f'{repository}/.checks/{uuid.uuid4().hex}'
    payload = b'Mockareel artifact storage round-trip check\n'
    s3.put_object(Bucket=BUCKET, Key=key, Body=payload)
    try:
        if s3.get_object(Bucket=BUCKET, Key=key)['Body'].read() != payload:
            raise ValueError('S3 round-trip contents differ')
    finally:
        s3.delete_object(Bucket=BUCKET, Key=key)
    print('SeaweedFS HTTPS upload, download and deletion verified.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['upload', 'download', 'prune', 'check'])
    parser.add_argument('--kind', choices=['debug', 'release'], default='debug')
    parser.add_argument('--directory', default='dist')
    parser.add_argument('--attempt', default=os.environ.get('GITHUB_RUN_ATTEMPT'))
    args = parser.parse_args()
    store = client()
    repository = os.environ['GITHUB_REPOSITORY']
    if args.command == 'prune':
        prune(store, repository)
    elif args.command == 'check':
        check(store, repository)
    else:
        prefix = bundle_prefix(repository, args.kind, os.environ['GITHUB_RUN_ID'], args.attempt)
        {'upload': upload, 'download': download}[args.command](store, prefix, args.directory)


if __name__ == '__main__':
    from botocore.exceptions import BotoCoreError, ClientError
    try:
        main()
    except ClientError as error:
        code = re.sub(r'[^A-Za-z0-9_.-]', '', error.response.get('Error', {}).get('Code', 'Unknown'))
        status = error.response.get('ResponseMetadata', {}).get('HTTPStatusCode', 'unknown')
        print(f'::error::SeaweedFS {error.operation_name} failed: {code} (HTTP {status}). '
              'Check S3 credentials and bucket permissions.', file=sys.stderr)
        sys.exit(1)
    except BotoCoreError as error:
        print(f'::error::SeaweedFS connection/client failure: {type(error).__name__}. '
              'Check HTTPS endpoint reachability, TLS trust and S3 client configuration.', file=sys.stderr)
        sys.exit(1)
