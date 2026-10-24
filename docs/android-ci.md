# Android builds and releases

Both workflows use Flutter **3.47.7**, Temurin **21**, Android SDK/build tools **36**, NDK **28.2.13676358**, CMake **3.22.1** and the checked-in Gradle **9.3.1** wrapper. External Actions are pinned to commit SHAs. The wrapper distribution has a pinned SHA-256 checksum.

## Debug APKs

**Android debug APK** runs on pushes and pull requests targeting `main` or `work`, and can be run manually. It checks release-version validation, Dart analysis, Flutter tests and native Android unit tests, then builds a universal debug APK. Download the APK and `.sha256` file from the run's **Artifacts** section (retained for 14 days).

Debug APKs use `dev.mockareel.mockareel.debug` and the launcher name **Mockareel Debug**, so they can coexist with release/preview APKs and keep separate project data. A fresh GitHub runner normally generates a fresh debug signing certificate. Optionally add repository secret `ANDROID_DEBUG_KEYSTORE_BASE64` with a standard Android debug keystore (alias `androiddebugkey`, store/key passwords `android`) to keep push/manual debug builds update-compatible. Pull request builds never restore signing secrets, including for same-repository branches; those APKs use a fresh runner key and may require uninstalling an older **debug** installation before installing. Release projects are unaffected.

Debug jobs never receive release signing keys or the Maps key. Configure Maps in the debug app's on-device Settings.

## Release signing: one-time configuration

In **Settings → Secrets and variables → Actions**, add these repository secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release keystore file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing key alias |
| `ANDROID_KEY_PASSWORD` | Signing key password |
| `MAPS_API_KEY` | Optional real Google client API key; omit to use on-device Settings |

Keep a backed-up signing key: subsequent releases must use the same key to update existing installations. Previous manually published previews were development-signed. To update those installations in place, supply that same existing key; a newly generated release key will require a separate installation/migration and cannot update the old APK in place. Portable project backups can transfer projects if you change keys. Do not commit signing material or passwords.

Encode an existing keystore locally with `base64 -w 0 /path/to/release.jks` on Linux (or `base64 -i /path/to/release.jks | tr -d '\n'` on macOS), then copy the value directly into the repository secret. Never paste it into an issue, PR or build log. The workflow decodes it into a temporary runner file and deletes it after building. It fails early if any required signing secret is missing; CI release builds cannot fall back to debug signing. Local development `flutter build apk --release` still uses the development key unless all four `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` environment variables are supplied.

An embedded Maps key can be extracted from an APK; apply suitable API/application restrictions. It is optional for builds and not needed for manual editing or FYP export.

## Publish a release

1. Merge the source and workflows into the default branch (`main`) to make manual Actions dispatch available in the GitHub UI. Push workflows and sources to `work` for automatic debug builds immediately; tag-triggered releases also work on source commits containing the release workflow.
2. Update `pubspec.yaml` to `version: X.Y.Z+BUILD`, increasing `BUILD` for every distributed release. Commit and push it.
3. Create and push a tag matching the name exactly, such as `vX.Y.Z` (`git tag -a vX.Y.Z -m 'Release X.Y.Z'`, then `git push origin vX.Y.Z`). Do not tag a commit that lacks the release workflow.
4. **Publish Android release** validates the tag against the checked-out version, runs the same checks as debug CI, builds and verifies the signed APK, and publishes a GitHub Release containing `mockareel-X.Y.Z-release.apk`, its SHA-256 checksum and generated release notes.

For a retry after fixing signing secrets or a transient failure, rerun the failed job; alternatively run **Publish Android release** manually with the existing tag. The tag must point to the checkout that declares that version. Versions containing a prerelease suffix (for example `1.0.0-beta.1+11`, tag `v1.0.0-beta.1`) publish as prereleases. Existing releases and their assets are never replaced; use a new version/tag for changed binaries.

Code or workflow fixes require a new version and tag: rerunning an old tag still checks out its original code. For example, the release-build fix after `v0.12.1` is included in `v0.12.2`.

Only the publish job has `contents: write`; it downloads the build artifact without checking out or executing repository code. Release secrets are restricted to the signing-configuration check and signing step; tests and publishing do not receive them. Both APKs are checked for signature validity, ZIP integrity, 16 KB ZIP alignment, expected package ID and version before upload. `.sha256` files can be verified with `sha256sum -c *.sha256` from the download directory.

These workflows publish GitHub Release assets and Actions artifacts. They do not upload to Google Play or modify the legacy `apk-preview` branch.

The APK build explicitly enables Flutter's pub step so Flutter regenerates plugin registration for the selected build mode. Dependency setup and tests include the dev-only `integration_test` plugin; release registration excludes it. Do not add `--no-pub` to the APK build: it also skips this regeneration and can leave a Java reference to a test plugin that is absent from the release build. The setup step enforces `pubspec.lock`, and the build uses the existing locked dependency versions.

## Local equivalents

With Flutter/Java/Android on `PATH` (in the cloud workspace, first `source tool/cloud_env.sh`):

```sh
flutter pub get --enforce-lockfile
bash tool/ci/check_android.sh
bash tool/ci/build_apk.sh debug
# With release signing environment variables configured:
MOCKAREEL_REQUIRE_RELEASE_SIGNING=true bash tool/ci/build_apk.sh release
```

Packaged APKs/checksums go to ignored `dist/`. Tests and builds run sequentially to avoid generated plugin-registration conflicts. Keep `dist/` empty between modes when preparing assets manually; each Actions job starts with a fresh checkout.
