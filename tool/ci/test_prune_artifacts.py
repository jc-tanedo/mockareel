"""Retention tests use a fake GitHub API; nothing is deleted remotely."""
import unittest
from prune_artifacts import prune


def artifact(identifier, name='release-assets', expired=False):
    return {'id': identifier, 'name': name, 'expired': expired,
            'workflow_run': {'id': identifier}, 'created_at': '2026-10-27T00:00:00Z'}


class PruneArtifactsTest(unittest.TestCase):
    def run_prune(self, artifacts, active=(), dry_run=False):
        deleted = []
        pages = []

        def api(endpoint, method='GET'):
            if method == 'DELETE':
                deleted.append(int(endpoint.rsplit('/', 1)[1]))
                return None
            if '/actions/runs/' in endpoint:
                run = int(endpoint.rsplit('/', 1)[1])
                return {'status': 'in_progress' if run in active else 'completed'}
            page = int(endpoint.rsplit('=', 1)[1])
            pages.append(page)
            return {'artifacts': artifacts[(page - 1) * 100:page * 100]}

        prune('owner/repo', api, dry_run)
        return deleted, pages

    def test_keeps_two_per_type_and_ignores_unrelated_and_expired(self):
        entries = [artifact(i) for i in range(1, 5)]
        entries += [artifact(i, f'mockareel-debug-{i}-1') for i in range(5, 9)]
        entries += [artifact(99, 'other'), artifact(100, expired=True)]
        deleted, _ = self.run_prune(entries)
        self.assertEqual(set(deleted), {1, 2, 5, 6})

    def test_does_not_delete_or_count_in_progress_release(self):
        deleted, _ = self.run_prune([artifact(i) for i in range(1, 5)], active={4})
        self.assertEqual(deleted, [1])

    def test_paginates_before_deleting(self):
        deleted, pages = self.run_prune([artifact(i) for i in range(1, 102)])
        self.assertEqual(pages, [1, 2])
        self.assertEqual(set(deleted), set(range(1, 100)))

    def test_dry_run_never_deletes(self):
        deleted, _ = self.run_prune([artifact(i) for i in range(1, 5)], dry_run=True)
        self.assertEqual(deleted, [])

    def test_fewer_than_three_never_deletes(self):
        for count in range(3):
            self.assertEqual(self.run_prune([artifact(i) for i in range(count)])[0], [])
