# Development

[← README](../README.md)

## Toolchain

Use Flutter 3.47.7, JDK 21, Android SDK/build tools 36, NDK 28.2.13676358 and CMake 3.22.1. Dependencies are pinned in `pubspec.lock`. Media3 versions match `video_player_android`; AGP 9 uses built-in Kotlin and the legacy Android DSL required by Flutter.

```sh
flutter pub get --enforce-lockfile
bash tool/ci/check_android.sh
bash tool/ci/build_apk.sh debug
```

On a managed Linux cloud workspace, `bash tool/setup_cloud.sh` installs the pinned toolchain; then `source tool/cloud_env.sh`. Ordinary local development and GitHub Actions do not need the cloud setup scripts.

Debug builds install as **Mockareel Debug** with a separate app ID. Packaged APKs/checksums are written to ignored `dist/`. For signed builds and publishing, see [Android CI](android-ci.md). Tests and builds run sequentially because they share generated plugin registration.

## Project structure

```text
lib/
  main.dart                 # Entry point
  app.dart                  # Application routing and theme wiring
  theme/                    # Shared editor design tokens and theme
  model/                    # Project, media, post, settings and timeline data
  pages/                    # Library, Maps/FYP editors, exported-video viewer
  services/                 # Storage, bounded backup imports, Maps, native bridge
  widgets/                  # Shared preview surfaces, inspectors and dialogs
android/app/src/main/kotlin/ # Android media rendering and gallery integration
test/                       # Dart model, widget, storage and export-surface tests
integration_test/           # Real-device media flow
tool/                       # CI helpers, cloud setup and optional visual tools
```

Models do not depend on UI. Widgets/pages do not import the entry point. Preview and export share the same output widgets; native Android code keeps active video as a texture and composites captured UI frames. The timeline helpers define motion consistently between preview and export.

The two editor pages still own substantial state, import and export orchestration. When extending them, prefer extracting focused controllers/services and inspectors over adding more responsibilities. A feature-per-template structure may become useful once more templates share these boundaries; avoid moving common preview/storage code into one template.

## Validation

`check_android.sh` runs release-metadata tests, Dart formatting, analysis, Flutter tests and Kotlin unit tests. CI does not run optional visual tools or device tests.

Host tests and a successful APK build do not verify device codecs, pickers, playback or MediaStore. The native encoding flow and live Maps Static requests still need physical-device verification:

```sh
flutter test integration_test/reel_flow_test.dart -d <device-id>
```

## Visual review

Reference recordings are not included in the repository. Layout notes are in [reference.md](reference.md). To generate reference crops from your own recording:

```sh
MOCKAREEL_REFERENCE_VIDEO=/path/to/reference.mp4 \
  flutter test tool/render_reference_preview_test.dart
```

The optional Maps, feed and editor render tools consume those generated crops. Some also require the second map/review recording in the cloud workspace; see their file headers and inputs before running. They write PNGs under `/tmp/` and demonstrate Flutter rendering, not native Android MP4 encoding.

## Brand assets

The film-reel fish mark and its [SVG/PNG sources](../assets/brand/) share one geometric definition. Android includes adaptive, monochrome, round and legacy icons. Regenerate with:

```sh
flutter test tool/generate_brand_assets_test.dart
```
