# Mockareel

A Flutter editor for vertical place reels. Android is the first video-export target.

## First template: Maps place story

The template follows the supplied screen recording: a map header (or optional photo), a white place sheet with editable details and teal action chips, and a horizontal gallery of rounded cards that scrolls left, snaps a card fully into view, then holds. Tabs, a place-specific footer button and hours stay fixed beneath the gallery. Movable text layers and decorative story controls can be added. The editor uses charcoal panels, violet selection highlights and a thumbnail timeline with a selected-clip inspector.

1. Find a place with Google Places or edit its details manually. New projects use a **Map** header: location lookup automatically requests a map image, or use **Header image → Load Google map / Upload map image**. Change map zoom and reload when needed. Photo headers remain available, and older projects retain their original photo mode. Choose **Output theme → Light / Dark** below the preview in Place to style the reel independently of the editor. The selection is saved per project and applies to the live preview, MP4, transparent PNG and snapshot PNG. **Template details** includes the alternate name, review count, price, hours and header-photo selection. **Template buttons** suggests actions from the place types and available phone/website; edit labels/icons, add/remove buttons, toggle the Menu tab, or replace the footer label. Non-food places do not get Menu by default.
2. Open **Timeline** and select photos and videos. Selected originals are copied into app storage so picker-cache expiry does not break projects.
3. Set durations, trim video starts, reorder cards, and add captions. **Card framing** controls width, height, zoom and horizontal crop. **Left-scroll snap** adjusts the entry speed; the reference-pace preset gives five cards a 7.8-second timeline.
4. Adjust **Opening scroll reveal** in Timeline (0 disables it; new projects default to 0.9 seconds). The place sheet slides up over the map before the gallery advances. **Featured review (optional)** in Place adds editable name, 1–5 star rating and text below the gallery. A blank or disabled review stays hidden.
5. Play and scrub the preview. After the opening reveal, the header/footer stay fixed as cards move inside the gallery. The active video plays; other video cards show their start/end frames while waiting or exiting.
6. Use **Text** to add multiple story-style tags: drag on the canvas, edit, duplicate, delete, choose a style/color, resize and rotate. Existing badges migrate into editable tags.
7. Use **Audio** to select device music, adjust volume/start offset, and loop to fit. Preview playback and scrubbing follow the reel clock. Original clip audio remains muted.
8. Export a 1080 × 1920 H.264 MP4 with an AAC soundtrack when music is selected, then play/share it or save it to `Movies/Mockareel` on Android 10+. Photos render at 30 fps; video cards retain their source cadence. Slide time is included in each card's duration.
9. Export a **Transparent template PNG** for compositing, or a **Full snapshot PNG** with the selected card. Both are 1080 × 1920. The cutout has real transparency in the gallery; optional captions remain part of the overlay.

Projects autosave, including when leaving the app. The folder button opens the project library or creates a new project. Portable `.mockareel` backups include originals, timings, framing, captions, header selection, music, text layers, map image, opening animation, featured review and output theme; they can be imported on another device. Older projects open with default framing.

## Google Places

The app uses **Places API (New)** Text Search. Enable it and billing in Google Cloud. Set a key with `--dart-define=MAPS_API_KEY=...` or enter it in the app's Settings. An on-device key takes precedence. Keys are not included in project backups or Git source. Google map headers additionally require **Maps Static API**, billing, and key restrictions that permit the request. They use the retrieved latitude/longitude, a location marker and selected zoom. Uploaded map images work without Maps Static API. Keep map attribution visible in images you upload.

`tool/build_android.sh` includes a real `MAPS_API_KEY` environment value when available; cloud secret-proxy placeholders cannot authenticate from a phone and are skipped. The script never prints the key. Manual editing and rendering need no Maps key.

## Development and verification

Use Flutter 3.47.7, JDK 21 and Android SDK 36. Media3 versions are aligned with `video_player_android`. AGP 9 built-in Kotlin is enabled; the Flutter Gradle plugin still requires the legacy Android DSL.

```sh
bash tool/setup_cloud.sh
source tool/cloud_env.sh
flutter analyze
flutter test
./android/gradlew -p android :app:testDebugUnitTest --tests dev.mockareel.mockareel.ScrollMotionTest
bash tool/build_android.sh
```

Run Flutter tests and APK builds sequentially: both regenerate plugin registration, so concurrent runs can leave a test-only plugin in the release registrant.

The APK is `build/app/outputs/flutter-apk/app-release.apk`. Version 0.6.0+6 uses the existing development signing key and can update the previous preview without uninstalling it.

Flutter tests cover narrow layouts, real PNG export/share flows, cutout alpha, fixed header/footer pixels, moving and snapped card positions, crop direction, duration/trim bounds, media ownership, backup restoration and Places requests. Four host-side Kotlin tests cover native sheet reveal, synchronized intro frames, entry motion and timestamp normalization for clipped/concatenated inputs.

**Native execution remains unverified on a device. Live Maps Static requests also need verification with the device’s configured key; this environment has no client key and does not allow the Maps Static host.** The cloud emulator's Android system services crashed during APK installation, before the device test could start. Passing host tests and building an APK do not establish that a device's codecs, picker, player or MediaStore work. The real-device test is included:

```sh
flutter test integration_test/reel_flow_test.dart -d <device-id>
```

Video export currently targets Android. Editor/models/storage stay in Dart for future platforms. Music is selected from device files; a licensed music catalog is not included. Simultaneous playback of neighboring video cards is not implemented.

## Visual reference review

The original reference is a recording of an editor, not the exported 9:16 reel. Recording chrome and the floating assistant button are excluded from the template. Layout measurements and timing are recorded in [docs/reference.md](docs/reference.md). The newer map/review reference is retained outside Git at `/workspace/mockareel-maps-reference.mp4`. Run `flutter test tool/render_maps_preview_test.dart` after the original reference render to generate a 6-second map/review animation as PNG frames under `/tmp/mockareel-maps-preview`; those frames use reference crops and demonstrate Flutter rendering. The supplied recording is retained outside the Git checkout at `/workspace/mockareel-reference.mp4` when available.

Generate a visual review using crops from that recording:

```sh
MOCKAREEL_REFERENCE_VIDEO=/path/to/reference.mp4 \
  flutter test tool/render_reference_preview_test.dart
```

This generates PNG frames under `/tmp/mockareel-reference-preview`. They demonstrate the Flutter template renderer; they are not a recording of native Android MP4 export.

## Download

The `apk-preview` branch holds installable APKs separately from source. Open the versioned APK while signed into GitHub with repository access and choose **Download raw file**. Source changes are on `work`.
