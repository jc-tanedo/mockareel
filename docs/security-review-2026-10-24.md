# Repository review · 24 October 2026

Baseline: `632f778` (source), plus all fetched remote branches/tags, including `apk-preview`. This review does not change repository visibility or rewrite history.

## Credential audit

**No credential matches were found in the reviewed source/history or APK contents. No credential rotation is indicated by these scans.** This is a scoped finding, not a guarantee that every possible secret format has been detected.

| Check | Scope | Result |
| --- | --- | --- |
| Gitleaks 8.24.3, redacted output | All 26 reachable commits at baseline | No findings |
| Expanded APK pattern scan | 10 distinct APK Git blobs; 3,374 ZIP entries; 579,587,708 unpacked bytes | No findings |
| Sensitive filenames in Git history | Environment files, private-key and keystore extensions | No matches |
| Current Dart formatting / analysis | App, tests and tools | Already clean at baseline; enforced in CI after this review |

APK checks covered Google client keys, GitHub tokens, AWS access IDs, private-key markers, Slack tokens and Stripe live-key patterns. Public APK signing certificates are expected metadata; they are not private signing keys. Embedded fixture video bytes are test data.

Reproduce the scans after fetching branches/tags:

```sh
gitleaks git --redact=100 --log-opts=--all
python3 tool/ci/scan_apk_secrets.py --history
```

Reports generated during this review contain rule names and locations, never matched credential values. Repository secrets, GitHub Actions caches/artifacts, release assets outside Git, forks and Google Cloud key restrictions were not inspected. Dependency CVE coverage and a penetration test were outside this review.

## Findings and changes

| Priority | Finding | Resolution |
| --- | --- | --- |
| Medium | Project ZIP imports had no overall extraction or file-count budgets. Malformed schemas could leave an import unusable. | Added bounded ZIP preflight and decompression, rejected unsafe paths, duplicate entries, links and encryption; normalized malformed fields and tested rollback. Existing portable-backup tests pass. Limits are documented in [SECURITY.md](../SECURITY.md). |
| Low | Debug signing secrets could be restored in same-repository PR builds after executing PR code. | Key restoration is now disabled for every PR. Push/manual builds can still use the optional stable debug key. Never reuse that key as a release key. |
| Low | Typical local credential filenames were not all ignored. | Added environment-file, private-key and signing-file ignore rules. This complements scanning; ignore rules do not remove secrets already in history. |
| Maintenance | The entry point contained 1,885 lines, including the app theme, Maps editor, search dialog and video viewer. Pages imported the entry point, and feed/project models depended on one another. | Reduced `main.dart` to startup, separated app/theme/pages/dialogs, named the Maps editor explicitly, and split post/clip/timeline models to remove that model cycle. |
| Maintenance | Dialog controllers had no owner responsible for disposal. Maps-key text incorrectly said the key was only used for search. | Added stateful, shared dialogs that dispose their controllers; corrected the Maps-key explanation. |
| Maintenance | A valid JSON file with an invalid project schema could block the library. | Skip that damaged entry and retain access to healthy projects; regression tested. |
| UX bug | Opening the keyboard in a wide editor replaced a Row with a Column, destroying the focused inspector field. | Kept a stable Flex/inspector element through the layout change. Regression covers keyboard connection, continued typing and autosave. |

A pinned, checksum-verified Gitleaks workflow now runs on pushes, PRs, manual requests and weekly. Dependabot checks pinned GitHub Actions. The Android check script also enforces Dart formatting.

## Remaining decisions before public visibility

- Enable GitHub secret scanning and push protection where available, private vulnerability reporting, and protection for `main` and release tags. These are repository settings; the review did not change them.
- Keep release keystores private. Previously distributed previews use a development certificate; follow [signing guidance](android-ci.md) before changing keys. Intentionally embedded client Maps keys are extractable from APKs and need API restrictions and quotas. Personal device keys live in app-private preferences, not encrypted storage.
- Review whether historical preview screenshots/reference crops are intended for public distribution. `apk-preview` and its history become public with the repository. No media was deleted during the review.
- APK binaries in a branch also increase full-clone size. The README uses a single-branch clone; prefer GitHub Release assets for future releases. Removing old artifact history would be a separate decision because it affects existing downloads.
- The repository already contains GPL v3.0. The README now links it; the license was preserved. This was not a third-party license/legal audit.

## Code-quality follow-up

The current small-app structure is understandable: independent models, services, shared widgets and template-specific pages. Dart formatting and analysis are clean. The two editor pages still hold substantial state and export orchestration; the next useful refactor is focused editor controllers and export/import services. Native renderer formatting is not yet enforced by a Kotlin formatter. A whole-app architecture framework or wholesale feature-folder migration is not needed for this cleanup.

The README is now a concise project overview with branding, build/license/platform badges, navigation, a template comparison and a quick start. Detailed usage, Maps setup, development and CI instructions live in linked guides. No screenshots of user-supplied media were added to the public-facing README.

## Verification

The change is verified with Dart formatting and analysis, 51 Flutter model/widget/export-surface tests, five native motion tests, five release-metadata tests, workflow linting, Markdown link checks and an Android APK build. New regression tests cover malicious archives and tablet keyboard focus. The keyboard regression failed against the previous layout and passes after the fix. None of these checks substitutes for physical-device codec testing.

Home-screen visual refinements are awaiting the owner's reference examples; this review does not claim the existing presets exactly match their respective operating systems.
