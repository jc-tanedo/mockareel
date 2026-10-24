# Security

Please report vulnerabilities through [GitHub's private vulnerability reporting](https://github.com/jc-tanedo/mockareel/security/advisories/new) when enabled. If that option is unavailable, contact the maintainer through their GitHub profile to arrange a private channel. Do not put API keys, private signing keys or personal project backups in public issues.

Mockareel is an early preview; security fixes target the latest source on `main`.

## Data and credentials

- Projects and copied media are stored on the device. `.mockareel` backups contain original media and project metadata and are not encrypted; share them deliberately.
- Personal Google API keys are stored in app-private preferences. This is not encrypted credential storage. They are excluded from project backups.
- A build-time Maps key is extractable from an APK. Use only a restricted client key, limit enabled APIs and quotas, and never embed server credentials.
- Release signing keys belong in GitHub Actions secrets or local environment configuration. They must not be committed to Git. Debug and release keys should be different.

## Repository checks

A pinned Gitleaks CLI scans reachable text history on pushes, pull requests and a weekly schedule. It redacts any matches. The optional `tool/ci/scan_apk_secrets.py` also scans compressed APK contents, which normal text-history scanning does not cover:

```sh
python3 tool/ci/scan_apk_secrets.py --history
python3 tool/ci/scan_apk_secrets.py build/app/outputs/flutter-apk/app-release.apk
```

The APK scanner flags Google client keys as well as private-credential patterns. An intentionally embedded restricted client key still needs human review. Pattern scans do not prove that a repository contains no credentials and do not assess external Actions artifacts, release assets outside Git, forks, cloud permissions or all third-party dependency vulnerabilities.

Before changing repository visibility, enable GitHub secret scanning/push protection where available and review the old `apk-preview` media/assets. Maintainers should protect `main` and release tags (`v*`) so only trusted source reaches signing jobs.

## Project imports

Untrusted backups are checked before payload decompression: bounded ZIP metadata, regular paths, no symlinks or encryption, and stored/deflated entries only. Imports allow up to 2 GiB of archive data, 1 GiB per entry, 4 GiB expanded data, 2,048 entries and 512 clips. Manifests are limited to 1 MiB. Multi-disk and ZIP64 backups are not supported. Actual decompression writes are bounded; failed imports remove partially extracted media. Archive filenames never select destination paths.

[Latest repository review](docs/security-review-2026-10-24.md) · [Release signing](docs/android-ci.md)
