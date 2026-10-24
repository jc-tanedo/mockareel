"""Run with python3 -m unittest discover -s tool/ci -p 'test_*.py'."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('release_metadata.py').resolve()


class ReleaseMetadataTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'ci@example.invalid')
        self.git('config', 'user.name', 'CI test')
        self.write_version('1.2.3+42')

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True).strip()

    def write_version(self, version):
        (self.root / 'pubspec.yaml').write_text(f'name: fixture\nversion: {version}\n')
        self.git('add', 'pubspec.yaml')
        self.git('commit', '-qm', 'Fixture version')

    def run_metadata(self, tag):
        env = dict(os.environ, RELEASE_TAG=tag, GITHUB_OUTPUT=str(self.root / 'output'))
        return subprocess.run(['python3', str(SCRIPT)], cwd=self.root, env=env, capture_output=True, text=True)

    def test_stable_annotated_tag_emits_exact_commit(self):
        self.git('tag', '-am', 'Release', 'v1.2.3')
        result = self.run_metadata('v1.2.3')
        self.assertEqual(result.returncode, 0, result.stderr)
        output = (self.root / 'output').read_text()
        self.assertIn('prerelease=false\n', output)
        self.assertIn(f'commit={self.git("rev-parse", "HEAD")}\n', output)

    def test_prerelease_is_marked_for_github(self):
        self.write_version('1.3.0-beta.1+43')
        self.git('tag', 'v1.3.0-beta.1')
        self.assertEqual(self.run_metadata('v1.3.0-beta.1').returncode, 0)
        self.assertIn('prerelease=true\n', (self.root / 'output').read_text())

    def test_wrong_version_never_creates_outputs(self):
        result = self.run_metadata('v9.9.9')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'output').exists())

    def test_a_tag_on_another_commit_is_rejected(self):
        self.git('tag', 'v1.2.3')
        self.git('commit', '--allow-empty', '-qm', 'Later commit')
        self.assertNotEqual(self.run_metadata('v1.2.3').returncode, 0)
        self.assertFalse((self.root / 'output').exists())

    def test_zero_build_number_is_rejected(self):
        self.write_version('1.2.4+0')
        self.git('tag', 'v1.2.4')
        self.assertNotEqual(self.run_metadata('v1.2.4').returncode, 0)
