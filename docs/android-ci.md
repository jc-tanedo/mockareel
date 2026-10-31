# Android builds and releases

Both workflows use Flutter **3.47.7**, Temurin **21**, Android SDK/build tools **36**, NDK **28.2.13676358**, CMake **3.22.1** and the checked-in Gradle **9.3.1** wrapper. External Actions are pinned to commit SHAs. The wrapper distribution has a pinned SHA-256 checksum.

## Self-hosted runners

All jobs use `runs-on: self-hosted`. Register an Ubuntu/Debian Linux **x64** runner with Bash and Git available for checkout. The runner account needs root or passwordless `sudo` when system dependencies are missing, plus writable home and tool-cache directories. Missing command-line tools (including Python and the release job's GitHub CLI) are installed through `apt`; existing tools are reused. Android jobs install/cache the pinned Java, Flutter and Android SDK components, and fetch locked Dart dependencies. The secret scan reuses Gitleaks 8.24.3 if present, otherwise downloads and verifies that version.

Persistent runners reuse installed toolchains. Gradle configuration is updated without duplicate settings, and the publish job clears its previous `dist/` before downloading this run's artifacts.

## Debug APKs

**Android debug APK** runs on pushes and pull requests targeting `main` or `work` (push builds also cover `poc/**` branches and the isolated `feature/streetview-template` development branch), and can be run manually. It checks release-version validation, Dart analysis, Flutter tests and native Android unit tests, then builds a universal debug APK. Push/manual builds upload an APK/checksum ZIP to SeaweedFS. Download it from the run's **Summary** using the 24-hour signed link; S3 objects remain until retention removes them. Pull requests build and test but do not upload artifacts or receive S3 credentials.

Debug APKs use `dev.mockareel.mockareel.debug` and the launcher name **Mockareel Debug**, so they can coexist with release/preview APKs and keep separate project data. Published push/manual builds require repository secret `ANDROID_DEBUG_KEYSTORE_BASE64`: a standard Android debug keystore with alias `androiddebugkey` and store/key passwords `android`. CI restores it to a private temporary file, selects that exact file in Gradle, verifies the APK's certificate against the restored key, and deletes the file afterward. The certificate SHA-256 is printed in the build log. Missing or invalid signing configuration stops the build instead of silently generating an incompatible key. Signing identity must survive runner replacements and cache eviction; build caches are not a keystore backup.

Set the secret from a trusted machine with GitHub CLI (the keystore contents go directly to the secret, not the terminal):

```sh
base64 < /path/to/debug.keystore | tr -d '\n' | gh secret set ANDROID_DEBUG_KEYSTORE_BASE64 --repo jc-tanedo/mockareel
```

Prefer the keystore that signed the currently installed debug APK, if it is still available on its build runner. Android cannot recover that private key from an APK. If it has been lost, create a dedicated debug key once, keep a backup, and configure the secret:

```sh
keytool -genkeypair -keystore mockareel-debug.keystore -storetype JKS \
  -alias androiddebugkey -storepass android -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname 'CN=Android Debug,O=Android,C=US'
```

A change of signer requires one final uninstall/reinstall; back up projects first. Later APKs signed with the same configured key can update the app without removing project data. Do not rotate this secret on every build. Pull request builds never restore signing secrets, including for same-repository branches; their disposable debug APKs are not published. Local development still uses Android's default debug key unless `MOCKAREEL_DEBUG_KEYSTORE_PATH` is supplied. Release signing remains separate.

Debug jobs never receive release signing keys or the Maps key. Configure Maps in the debug app's on-device Settings.

## Artifact storage

Build bundles are stored at **https://bucket.s3.jczr.dev**, bucket **gh-artifact-store**, using S3 Signature V4, path-style addressing and region `us-east-1`. The bucket can remain private. Configure repository variable `S3_ACCESS_KEY_ID` and repository secret `S3_SECRET_ACCESS_KEY`. The identity needs `ListBucket` plus `GetObject`, `PutObject` and `DeleteObject` under `jc-tanedo/mockareel/`. No AWS account is needed.

Each bundle uses `<owner>/<repo>/<debug|release>/<run-id>-<attempt>/artifact.zip` plus a SHA-256 manifest written after upload. Only APKs, their checksums and release notes are included. Release publishing downloads the exact build attempt's bundle from S3, verifies its digest and filenames, then publishes normal GitHub Release assets. Rerunning only the publish job still uses the original build attempt.

**Retain latest APK artifacts** runs after each debug/release workflow completes, or manually from Actions. It keeps the two newest completed bundles per type across branches and removes older bundles and incomplete uploads from finished runs. Active runs and unrelated objects are preserved. The bucket's own lifecycle rules can expire files sooner; use no expiry rules on this prefix if the newest two must remain indefinitely. Legacy GitHub Actions artifacts still use the previous two-bundle cleanup; new uploads use S3 exclusively. GitHub Release APKs/checksums are unaffected.

The run summary contains a download link valid for 24 hours. Anyone who can read that link can use it until expiry; no public bucket policy is required. After expiry, generate a new link using an S3 client, or fetch the permanent `s3://` URI shown beside it. These downloads do not appear in GitHub's built-in **Artifacts** tab.

Manually run **Retain latest APK artifacts** to test HTTPS upload, read-back and deletion with a tiny temporary object under `<owner>/<repo>/.checks/`, followed by cleanup. S3 setup installs pinned, hash-verified Python dependencies into runner temporary storage without root privileges. Credentials are injected only into S3 operations, never tests or pull-request builds. For a quick authenticated download with AWS CLI configured for the same endpoint/key:

```sh
aws --endpoint-url https://bucket.s3.jczr.dev --region us-east-1 s3 cp \
  s3://gh-artifact-store/jc-tanedo/mockareel/debug/RUN_ID-ATTEMPT/artifact.zip .
```

## Release signing: one-time configuration

In **Settings → Secrets and variables → Actions**, add these repository secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release keystore file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing key alias |
| `ANDROID_KEY_PASSWORD` | Signing key password |

Keep a backed-up signing key: subsequent releases must use the same key to update existing installations. Previous manually published previews were development-signed. To update those installations in place, supply that same existing key; a newly generated release key will require a separate installation/migration and cannot update the old APK in place. Portable project backups can transfer projects if you change keys. Do not commit signing material or passwords.

Encode an existing keystore locally with `base64 -w 0 /path/to/release.jks` on Linux (or `base64 -i /path/to/release.jks | tr -d '\n'` on macOS), then copy the value directly into the repository secret. Never paste it into an issue, PR or build log. The workflow decodes it into a temporary runner file and deletes it after building. It fails early if any required signing secret is missing; CI release builds cannot fall back to debug signing. Local development `flutter build apk --release` still uses the development key unless all four `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` environment variables are supplied.

Official release jobs do not inject a shared Maps key and scan APK contents for credential patterns. Browser Maps search/header capture and exports need no key. Users can add their own API key under **Advanced · Google Maps**. Developers can still provide `MAPS_API_KEY` for custom local builds; such embedded keys are extractable.

## Publish a release

1. Merge the source and workflows into the default branch (`main`) to make manual Actions dispatch available in the GitHub UI. Push workflows and sources to `work` for automatic debug builds immediately; tag-triggered releases also work on source commits containing the release workflow.
2. Update `pubspec.yaml` to `version: X.Y.Z+BUILD`, increasing `BUILD` for every distributed release. Commit and push it.
3. Create and push a tag matching the name exactly, such as `vX.Y.Z` (`git tag -a vX.Y.Z -m 'Release X.Y.Z'`, then `git push origin vX.Y.Z`). Do not tag a commit that lacks the release workflow.
4. **Publish Android release** validates the tag against the checked-out version, runs the same checks as debug CI, builds and verifies the signed APK, and publishes a GitHub Release containing `mockareel-X.Y.Z-release.apk`, its SHA-256 checksum and release notes. A checked-in `docs/releases/vX.Y.Z.md` is prepended to the generated changelog when present.

For a retry after fixing signing secrets or a transient failure, rerun the failed job; alternatively run **Publish Android release** manually with the existing tag. The tag must point to the checkout that declares that version. Versions containing a prerelease suffix (for example `1.0.0-beta.1+11`, tag `v1.0.0-beta.1`) publish as prereleases. Existing releases and their assets are never replaced; use a new version/tag for changed binaries.

Code or workflow fixes require a new version and tag: rerunning an old tag still checks out its original code. For example, the release-build fix after `v0.12.1` is included in `v0.12.2`.

Only the publish job has `contents: write`; it checks out the exact validated build commit to install missing publishing tools, then downloads the build artifact. Release secrets are restricted to the signing-configuration check and signing step; tests and publishing do not receive them. Both APKs are checked for signature validity, ZIP integrity, 16 KB ZIP alignment, expected package ID and version before upload. `.sha256` files can be verified with `sha256sum -c *.sha256` from the download directory.

These workflows publish GitHub Release assets and SeaweedFS build bundles. They do not upload to Google Play or modify the legacy `apk-preview` branch.

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

Packaged APKs/checksums go to ignored `dist/`. Tests and builds run sequentially to avoid generated plugin-registration conflicts. Keep `dist/` empty between modes when preparing assets manually; Actions checkouts clean the workspace, and publishing explicitly clears previous artifacts before downloading.
