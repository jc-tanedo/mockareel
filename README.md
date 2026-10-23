# Mockareel

Mockareel is a Flutter editor for vertical place-story reels. The first template recreates the Google Maps Place story shown in the reference clip.

## Current editor

- Search for a place by opening Google Maps with the current place name, then edit the place title, category, rating, and location in the app.
- Add multiple photos and videos from the device library.
- Edit scene timing and review the five-card left-scroll story.
- Save an editable project draft on the device or share its JSON project description.

With a developer-supplied Places API key, in-app search fetches the selected place's title, category, rating and address. Without a key, the app opens Google Maps search and supports manual editing. A missing key does not prevent building or using the editor.

Project data contains media paths rather than copies of the selected media. Rendering a finished MP4, video playback, and portable project import are still pending; the current export shares the project description as JSON text.

## Run and build

The Android project uses Flutter 3.47.7, JDK 21, Android SDK 36, and NDK 28.2.13676358. From this directory with those tools installed:

```sh
flutter pub get
flutter run
flutter build apk --release
```

The release APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

The current release configuration uses the generated Android debug signing key for installation during development. A production release needs a separate signing configuration.

## Cloud development

The existing checkout is `/workspace/mockareel`. SDKs and caches live outside the checkout in `/workspace/.tooling`. Use the existing checkout rather than creating a Git worktree.

```sh
bash tool/setup_cloud.sh
source tool/cloud_env.sh
flutter analyze
flutter test
flutter build apk --release
```

Setup checks the SDK archive hashes, keeps TLS verification enabled, configures the Java proxy, and redirects tool caches to writable locations. Dart's native build hooks also need a one-time `dart --disable-analytics` initialization; if the sandbox rejects its configuration write, initialize `/home/agent/.dart-tool` with filesystem escalation rather than changing `HOME`.

For development with live place lookup, build with a real Places API key supplied using `--dart-define=MAPS_API_KEY=...`. This embeds the key in the APK. A cloud proxy secret placeholder cannot serve as a phone's API key; production lookup needs an appropriate mobile SDK or server integration. Live Google lookup cannot be validated without credentials.
