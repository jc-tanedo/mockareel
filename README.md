# Mockareel

A Flutter editor for vertical Google Maps style place reels. Android is the first export target.

## Use the app

1. Find a place with Google Places or enter the name, category, rating and address yourself. All fields stay editable.
2. Open **Timeline** and select photos and videos. Every selected file is copied into private app storage so a gallery cleanup or picker cache expiry will not break a saved project.
3. Reorder clips, set each duration, trim the start of videos, and add captions. Play and scrub the composed preview.
4. Open **Export → Render MP4**. When rendering finishes, play the actual MP4, share it, or save it to `Movies/Mockareel` on Android 10+.
5. Projects autosave. The folder button opens the project library or creates a new project. Project backups include all media and can be imported on another device.

Exports are silent H.264 MP4s, 720 × 1280. Photo scenes render at 30 fps with a gentle zoom; video scenes retain their source cadence. Clips use cuts between scenes. There is no audio/music editor or animated left-scroll transition yet. Native video export currently supports Android only; platform-independent models/editor code stay in Dart.

## Google Places

The app uses **Places API (New)** Text Search. Enable that API and billing in Google Cloud. Supply a client key with `--dart-define=MAPS_API_KEY=...` or enter it in the app's settings. A key saved in the app takes precedence over a build-time key. Restrict client keys to the required APIs and configure restrictions compatible with your deployment. Keys are never included in project backups or Git source.

The cloud environment's secret proxy may expose only a placeholder usable from cloud requests. Such a placeholder cannot be compiled into a phone APK. `tool/build_android.sh` includes a real `MAPS_API_KEY` environment value when available and otherwise leaves search configurable on device. It does not print the key.

## Development

Use Flutter 3.47.7, JDK 21 and Android SDK 36. The first export target uses AndroidX Media3 Transformer; Media3 versions are aligned with `video_player_android`. The Flutter Gradle plugin currently requires the legacy Android DSL; Kotlin compilation is enabled through AGP 9's built-in Kotlin support.

```sh
bash tool/setup_cloud.sh
source tool/cloud_env.sh
flutter analyze
flutter test
bash tool/build_android.sh
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. Development APKs use the existing development signing key. Version 0.2.0+2 can update the previous preview without uninstalling it, provided that signing key is preserved.

With an Android device/emulator connected:

```sh
flutter test integration_test/reel_flow_test.dart -d <device-id>
```

The device test creates a photo → trimmed video with source audio → photo project, plays the preview, uses the real native MP4 renderer, checks duration, resolution and muted audio, saves to MediaStore, and restores a portable backup with media. Unit/widget tests cover timeline boundaries, trimming, narrow layouts, save/reopen, durable media ownership, backup restoration, and Places request/error handling. Live Places lookup additionally needs a valid key.

## Download

The `apk-preview` branch holds the installable preview APK separately from application source. Open its `mockareel-preview.apk` file while signed into GitHub with repository access and choose **Download raw file**.
