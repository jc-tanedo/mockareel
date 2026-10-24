# Contributing

[Development guide](docs/development.md) · [User guide](docs/user-guide.md) · [Security reports](SECURITY.md)

Use the pinned toolchain and run `flutter pub get --enforce-lockfile`, then `bash tool/ci/check_android.sh` before opening a pull request. This checks formatting, analysis, Flutter tests, release-metadata validation and native unit tests. Run tests and APK builds sequentially.

Keep changes focused. Include a short description of the problem and resulting behavior, relevant screenshots for UI changes, and the checks you ran. For output changes, test the shared preview/export surfaces and preserve older saved-project defaults. Add regression coverage for bugs or security-sensitive behavior rather than tests that merely repeat implementation details.

Use `dart format` for Dart source. Keep shared models independent of UI, and place platform-specific rendering in Android code. Template inspectors belong with the corresponding editor; shared preview, storage and API logic belong in their existing common layers.

Never commit personal media, reference recordings, API keys or keystores. Use your own recordings when running optional visual tools. Do not update signing configuration or publish releases from a pull request.
