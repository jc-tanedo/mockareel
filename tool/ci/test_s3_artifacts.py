"""In-memory S3 regression tests; no real credentials or buckets are used."""
import io
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from s3_artifacts import BUCKET, bundle_prefix, check, download, prune, sha256_file, upload


class FakeS3:
    def __init__(self):
        self.objects = {}
        self.modified = {}

    def put_object(self, Bucket, Key, Body, **kwargs):
        assert Bucket == BUCKET
        self.objects[Key] = Body
        self.modified[Key] = len(self.objects)

    def get_object(self, Bucket, Key):
        return {'Body': io.BytesIO(self.objects[Key])}

    def delete_object(self, Bucket, Key):
        self.objects.pop(Key, None)

    def upload_file(self, path, bucket, key, **kwargs):
        self.put_object(Bucket=bucket, Key=key, Body=Path(path).read_bytes())

    def download_file(self, bucket, key, path):
        Path(path).write_bytes(self.objects[key])

    def get_paginator(self, operation):
        assert operation == 'list_objects_v2'
        return self

    def paginate(self, Bucket, Prefix):
        # Multiple pages, including an empty page, exercise full collection.
        yield {}
        for key in sorted(self.objects):
            if key.startswith(Prefix):
                yield {'Contents': [{'Key': key, 'LastModified': self.modified[key]}]}


class S3ArtifactsTest(unittest.TestCase):
    def setUp(self):
        self.s3 = FakeS3()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.dist = self.root / 'dist'
        self.dist.mkdir()
        (self.dist / 'mockareel-debug.apk').write_bytes(b'APK fixture')
        (self.dist / 'mockareel-debug.apk.sha256').write_text('fixture checksum')
        (self.dist / 'secret.jks').write_bytes(b'must never upload')

    def test_hashing_supports_system_python_without_file_digest(self):
        data = b'fixture' * 200000
        path = self.root / 'large-file'
        path.write_bytes(data)
        with patch.object(hashlib, 'file_digest', None, create=True):
            self.assertEqual(sha256_file(path), hashlib.sha256(data).hexdigest())

    def test_round_trip_and_only_allowed_files_uploaded(self):
        prefix = bundle_prefix('owner/repo', 'release', 1, 2)
        with patch.dict('os.environ', {}, clear=True):
            upload(self.s3, prefix, self.dist)
        output = self.root / 'download'
        download(self.s3, prefix, output)
        self.assertEqual(sorted(p.name for p in output.iterdir()),
                         ['mockareel-debug.apk', 'mockareel-debug.apk.sha256'])
        self.assertEqual((output / 'mockareel-debug.apk').read_bytes(), b'APK fixture')

    def test_tampered_archive_rejected_before_extraction(self):
        with patch.dict('os.environ', {}, clear=True):
            upload(self.s3, 'bundle/', self.dist)
        self.s3.objects['bundle/artifact.zip'] += b'corruption'
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            download(self.s3, 'bundle/', self.root / 'download')
        self.assertFalse((self.root / 'download').exists())

    def test_incomplete_bundle_without_checksum_not_uploaded(self):
        (self.dist / 'mockareel-debug.apk.sha256').unlink()
        with self.assertRaises(ValueError):
            upload(self.s3, 'bundle/', self.dist)
        self.assertEqual(self.s3.objects, {})

    def test_two_per_type_active_and_unrelated_preserved_partial_cleaned(self):
        for kind in ('debug', 'release'):
            for run in range(1, 5):
                prefix = bundle_prefix('owner/repo', kind, run, 1)
                for name in ('artifact.zip', 'manifest.json'):
                    self.s3.put_object(Bucket=BUCKET, Key=prefix + name, Body=b'fixture')
        self.s3.put_object(Bucket=BUCKET, Key='owner/repo/debug/99-1/artifact.zip', Body=b'partial')
        self.s3.put_object(Bucket=BUCKET, Key='other/repo/debug/1-1/artifact.zip', Body=b'other')
        self.s3.put_object(Bucket=BUCKET, Key='owner/repo/debug/notes.txt', Body=b'unrelated')
        prune(self.s3, 'owner/repo', lambda _: {'status': 'in_progress' if _.endswith('/4') else 'completed'})
        for kind in ('debug', 'release'):
            self.assertNotIn(f'owner/repo/{kind}/1-1/artifact.zip', self.s3.objects)
            for run in (2, 3, 4):
                self.assertIn(f'owner/repo/{kind}/{run}-1/artifact.zip', self.s3.objects)
        self.assertNotIn('owner/repo/debug/99-1/artifact.zip', self.s3.objects)
        self.assertIn('other/repo/debug/1-1/artifact.zip', self.s3.objects)
        self.assertIn('owner/repo/debug/notes.txt', self.s3.objects)

    def test_storage_check_removes_its_probe(self):
        check(self.s3, 'owner/repo')
        self.assertEqual(self.s3.objects, {})

    def test_prefix_rejects_path_traversal_and_invalid_run(self):
        for args in [('owner/repo/../../elsewhere', 'debug', 1, 1),
                     ('owner/repo', 'debug', '../1', 1)]:
            with self.assertRaises(ValueError):
                bundle_prefix(*args)
