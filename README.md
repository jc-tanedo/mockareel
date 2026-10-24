# Mockareel

A Flutter editor for vertical reels that recreate familiar app interfaces. Android is the first video-export target.

## Project library

The app opens to a grid of saved projects with previews of their output. **New project** opens the template gallery: choose **Maps place story** or **TikTok FYP scroll**. The editor’s back arrow returns to the library and saves your changes. Import portable backups with the file icon in the library. Existing Maps projects remain available after upgrading.

## TikTok FYP scroll

Four suggested steps use the same pinned-preview workspace and charcoal/violet editor design: **Sequence → Posts → Audio (optional) → Export**.

1. **Sequence:** open with a typed search, a home-screen app launch, or directly in the feed. A blank search skips the search scene. Set typing time, loading time and vertical swipe duration. Optionally close the app back to the home screen.
2. **Home screen & status bar:** choose iPhone (iOS), Android, Google Pixel or Samsung One UI. Each preset has its own widget, icon shape, dock and launcher navigation. Choose a photo/video wallpaper, edit time/date and widget text, and customize eight app labels and icon presets. **Show mock app icons** toggles the grid, dock and launcher navigation without discarding labels. Clock/date, widget and status bar have independent switches. When media is present, **Use media without overlays** hides all generated home chrome and removes its dimming, so a supplied screenshot displays without duplicate icons or widgets. The fourth tile launches/receives the app. Home hold duration is editable; short video wallpapers loop. The app launch/close animation uses a still of the first/last post.
3. **Posts:** add photos/videos; each becomes a full-screen post. Select a post and use **Identity** (username, profile photo, verification/following), **Caption** (title, caption/hashtags, sound label), **Stats** (likes, comments, saves, shares), or **Timing & frame** (duration, trim, zoom, horizontal crop, reorder/remove). Sidebar and post text slide upward with each post; navigation stays fixed. The outgoing video holds its last frame during a swipe while the incoming video plays.
4. **Audio:** select actual background music, volume, start offset and looping. The per-post sound label is decorative. Source video audio is muted.
5. **Export:** render a 1080×1920, 30 fps H.264 MP4, with AAC when music is present; share or save it to the gallery. The native renderer retains moving video textures and composites UI frames during typing, loading, swipes, launch and close.

Autosave and `.mockareel` backups include all per-post fields, avatars, home media, sequence settings and music. No account or network connection is needed for this template. These are editable visual mockups; the buttons do not navigate to live social profiles.


## First template: Maps place story

The template follows the supplied screen recording: a map header (or optional photo), a white place sheet with editable details and teal action chips, and a horizontal gallery of rounded cards that scrolls left, snaps a card fully into view, then holds. Tabs, a place-specific footer button and hours stay fixed beneath the gallery. Movable text layers and decorative story controls can be added. The editor uses charcoal panels, violet selection highlights and a thumbnail timeline with a selected-clip inspector.

The editor follows five suggested steps: **Place → Timeline → Text (optional) → Audio (optional) → Export**. Numbered navigation and a **Next** action make the sequence explicit; every step remains freely accessible. A pinned preview sits above a focused inspector; expand the preview for a larger view. On wider screens, preview and inspector sit side by side. When typing, the inspector gets the workspace.

1. **Place → Details:** find a Google place or edit its name, category and address. **More place details** holds rating, local name, review count, price and hours.
2. **Place → Look:** choose the output's Light/Dark theme and optional decorative story controls. This setting is independent of the editor's appearance.
3. **Place → Header:** use a Google map, upload a map image or choose a header photo. Set zoom and load again to refresh. New projects use Map; older projects retain their previous header.
4. **Place → Buttons / Review:** customize suggested actions, footer and Menu visibility, or add an optional featured review. A blank or disabled review stays hidden.
5. **Timeline:** add photos/videos and select a thumbnail. **Timing** holds duration, video trim, caption and reorder controls; **Frame** holds card width/height, zoom and crop; **Motion** holds opening reveal, slide speed and reference pacing. Original media is copied into app storage. Small screens use a compact clip selector. Long-press thumbnails to see filenames.
6. **Text:** add movable text layers, tap a layer to style it, duplicate or delete it. Size, rotation and centering are under **Transform**.
7. **Audio:** choose device music and adjust volume. **Timing & loop** holds the start offset and looping controls. Preview playback and scrubbing follow the reel clock. Original clip audio stays muted; skip this step for silent output.
8. **Export:** review format and duration, then use the pinned **Render MP4** action. A missing map header links back to its setup panel. **Still images** holds transparent-template and full-snapshot PNG exports. MP4 is 1080×1920 H.264 with AAC when music is present; PNGs are 1080×1920 with real gallery alpha for the cutout.
9. The project title opens renaming; the back arrow returns to saved projects. **More project options** includes Maps API settings, rename and portable backups. Projects autosave; explicit Save remains in the header.

Projects autosave, including when leaving the app. The library opens and creates projects. Portable `.mockareel` backups include originals, timings, framing, captions, header selection, music, text layers, map image, opening animation, featured review and output theme; they can be imported on another device. Older projects open with default framing.

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

The APK is `build/app/outputs/flutter-apk/app-release.apk`. Version 0.10.0+10 uses the existing development signing key and can update the previous preview without uninstalling it.

Flutter tests cover suggested-step navigation, optional-step skipping, screen-reader actions, pinned/expanded previews, keyboard editing, short-phone/landscape layouts, real PNG export/share flows, cutout alpha, fixed header/footer pixels, moving and snapped card positions, crop direction, duration/trim bounds, media ownership, backup restoration and Places requests. Five host-side Kotlin tests cover native sheet reveal, synchronized intro frames, vertical feed entry/frame synchronization, horizontal entry motion and timestamp normalization for clipped/concatenated inputs.

**Native execution remains unverified on a device. Live Maps Static requests also need verification with the device’s configured key; this environment has no client key and does not allow the Maps Static host.** The cloud emulator's Android system services crashed during APK installation, before the device test could start. Passing host tests and building an APK do not establish that a device's codecs, picker, player or MediaStore work. The real-device test is included:

```sh
flutter test integration_test/reel_flow_test.dart -d <device-id>
```

Video export currently targets Android. Editor/models/storage stay in Dart for future platforms. Music is selected from device files; a licensed music catalog is not included. Simultaneous playback of neighboring video cards is not implemented.

## Visual reference review

The original reference is a recording of an editor, not the exported 9:16 reel. Recording chrome and the floating assistant button are excluded from the template. Layout measurements and timing are recorded in [docs/reference.md](docs/reference.md). The newer map/review reference is retained outside Git at `/workspace/mockareel-maps-reference.mp4`. Run `flutter test tool/render_maps_preview_test.dart` after the original reference render to generate a 6-second map/review animation as PNG frames under `/tmp/mockareel-maps-preview`; those frames use reference crops and demonstrate Flutter rendering. The supplied recording is retained outside the Git checkout at `/workspace/mockareel-reference.mp4` when available.

Run `flutter test tool/render_feed_preview_test.dart` after generating the reference crops to review the library, template gallery, feed editor and search/feed/home scenes under `/tmp/mockareel-feed-preview`. These are Flutter renders, not native-device recordings.

Generate a visual review using crops from that recording:

```sh
MOCKAREEL_REFERENCE_VIDEO=/path/to/reference.mp4 \
  flutter test tool/render_reference_preview_test.dart
```

This generates PNG frames under `/tmp/mockareel-reference-preview`. They demonstrate the Flutter template renderer; they are not a recording of native Android MP4 export.

## GitHub Actions

[Android CI and release setup](docs/android-ci.md) documents automatic debug APKs, signed version-tag releases, required signing secrets and local equivalents. Debug APKs install separately as **Mockareel Debug**. Release publishing requires the repository signing secrets; no signing keys are stored in Git.

## Download

The `apk-preview` branch holds installable APKs separately from source. Open the versioned APK while signed into GitHub with repository access and choose **Download raw file**. Source changes are on `work`.

## App icon

The film-reel fish mark uses a circular reel with four punched reel holes, a center spindle, a forked tail and a small eye/mouth. Lavender `#B1A6FF` on charcoal `#202023` matches the editor. [Brand assets](assets/brand/) include transparent SVG/PNG glyphs, a monochrome SVG, a 1024-pixel launcher icon and a size-review sheet.

Android uses adaptive vector foreground/background layers, round and legacy launchers at every density, and a monochrome layer for Android 13 themed icons. Geometry stays inside the adaptive icon safe zone. Regenerate these assets from one geometry source with `flutter test tool/generate_brand_assets_test.dart`.
