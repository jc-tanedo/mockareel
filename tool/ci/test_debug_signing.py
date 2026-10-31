import base64
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from debug_signing import restore, verify_signer


class DebugSigningTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.environment = {
            'RUNNER_TEMP': str(self.root),
            'GITHUB_ENV': str(self.root / 'environment'),
            'DEBUG_KEYSTORE_BASE64': base64.b64encode(b'test-key').decode(),
        }

    def test_missing_secret_and_invalid_encoding_do_not_generate_a_new_key(self):
        for encoded in ['', 'invalid!']:
            with self.subTest(encoded=encoded):
                self.environment['DEBUG_KEYSTORE_BASE64'] = encoded
                with self.assertRaises(ValueError):
                    restore(self.environment)
                self.assertEqual(list(self.root.iterdir()), [])

    @patch('debug_signing.subprocess.run')
    def test_restored_key_and_signer_are_stable_across_independent_jobs(self, command):
        command.return_value.stdout = b'public-certificate'
        first, fingerprint = restore(self.environment)
        second, other = restore(self.environment)
        self.assertNotEqual(first, second)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        self.assertEqual(first.stat().st_mode & 0o777, 0o600)
        self.assertEqual(first.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(fingerprint, other)
        self.assertIn(f'MOCKAREEL_DEBUG_KEYSTORE_PATH={second}', Path(self.environment['GITHUB_ENV']).read_text())
        self.assertIn('androiddebugkey', command.call_args.args[0])

    @patch('debug_signing.subprocess.run', side_effect=subprocess.CalledProcessError(1, 'keytool'))
    def test_wrong_keystore_is_removed_and_never_selected(self, command):
        with self.assertRaises(ValueError):
            restore(self.environment)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_packaging_rejects_a_different_or_additional_signer(self):
        output = 'Signer #1 certificate SHA-256 digest: abc123\n'
        verify_signer(output, 'ABC123')
        for invalid in ['', output.replace('abc123', 'def456'), output + 'Signer #2 certificate SHA-256 digest: abc123\n']:
            with self.assertRaises(ValueError):
                verify_signer(invalid, 'abc123')
