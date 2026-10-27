#!/usr/bin/env python3
"""Keep two completed-build artifact bundles per type; never touch release assets."""
import argparse
import json
import os
import subprocess


def github_api(endpoint, method='GET'):
    result = subprocess.run(
        ['gh', 'api', '--method', method, endpoint],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout) if result.stdout.strip() else None


def prune(repository, api=github_api, dry_run=False):
    # Collect all pages before deleting: deletion would otherwise shift pagination.
    artifacts = []
    page = 1
    while True:
        batch = api(f'repos/{repository}/actions/artifacts?per_page=100&page={page}')['artifacts']
        artifacts.extend(batch)
        if len(batch) < 100:
            break
        page += 1

    completed = {}
    groups = {'debug': [], 'release': []}
    for artifact in artifacts:
        name = artifact['name']
        group = 'debug' if name.startswith('mockareel-debug-') else (
            'release' if name == 'release-assets' else None
        )
        if group is None or artifact['expired']:
            continue
        run_id = artifact['workflow_run']['id']
        if run_id not in completed:
            run = api(f'repos/{repository}/actions/runs/{run_id}')
            completed[run_id] = run['status'] == 'completed'
        # A release's build artifact must survive until publishing finishes.
        if completed[run_id]:
            groups[group].append(artifact)

    for group, entries in groups.items():
        entries.sort(key=lambda artifact: (artifact['created_at'], artifact['id']), reverse=True)
        print(f'{group}: retaining {min(2, len(entries))} newest completed-build bundles')
        for artifact in entries[2:]:
            print(f'{"Would delete" if dry_run else "Deleting"} {artifact["name"]} (artifact {artifact["id"]})')
            if not dry_run:
                api(f'repos/{repository}/actions/artifacts/{artifact["id"]}', 'DELETE')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    prune(os.environ['GITHUB_REPOSITORY'], dry_run=args.dry_run)
