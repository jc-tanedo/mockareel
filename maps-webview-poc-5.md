# Maps WebView POC 5 · preview slides and final-frame pause

[Download test APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-maps-webview-poc-5.apk) · [SHA-256](mockareel-maps-webview-poc-5.apk.sha256)

Updates **Mockareel Maps POC**, keeping existing projects. Package `dev.mockareel.mockareel.mapspoc`, version `0.13.0-maps-poc.5+21`, same development signing identity. No Google API key is embedded.

Source: [poc/maps-webview-search](https://github.com/jc-tanedo/mockareel/tree/poc/maps-webview-search), commit `ff0b24ba91a094684d1e8d1d5bb4cfbcc0e8a98d`. Stable `main` and `work` are unchanged.

## Preview fixes

- Maps gallery cards and FYP posts retain a stable player as they change from upcoming to active to outgoing. The next card preloads, and outgoing media holds its last frame, avoiding player-to-poster swaps and decoder restarts during slides.
- The timeline stops before rebuilding its final frame. Playback is also bounded by the reel/clip duration. Media synchronization is serialized and coalesced so a delayed play cannot overtake the final pause.
- Paused GIFs seek at/before the final real 30 fps frame. Comparisons use native millisecond units, avoiding repeated seeks on held cards. Initial GIF player loading no longer waits for the timing-edit debounce.
- If GIF classification arrives after a photo preview was first created, the preview switches to the controlled player instead of leaving an independently animated image active.

**The export services, GIF segment encoder/cache and Android native encoding code are unchanged from POC 4**, whose exported output the user confirmed was correct. Still/capture mode retains its poster path. This update changes live preview behavior and includes a version bump for installation.

## Try it

1. Open the same saved GIF project and play through the media slides.
2. Watch for flashes as a card enters, becomes active and slides away.
3. Let playback reach the end. The final media should stay paused, with the Play control visible. Wait a few seconds to confirm it remains still.
4. Restart or scrub the preview; GIF timing and looping controls remain available.

## Validation

85 Flutter tests, six Kotlin tests, five release-metadata tests, formatting and Dart analysis passed. New regression checks retain actual GIF preview controllers through Maps slides, preserve preloaded FYP players before/during/after a swipe, verify held cards do not repeatedly seek, simulate a delayed native play command and assert the final native state is paused, verify timeline EOF remains paused, and cover GIF classification after initial rendering. Existing GIF preparation/export, capture and FYP handoff checks pass.

APK signature/package/version, ZIP integrity, 16 KB alignment and credential-pattern checks passed. The playback tests use a fake video platform to control race timing; visual smoothness on the affected Android device still needs checking.

SHA-256: `75d81e750c12ad6a4f7465d9267dd875bfbdcfe74cdede5a4bc83bfb247ba06b`.

[Previous POC 4](maps-webview-poc-4.md) · [POC 3](maps-webview-poc-3.md). Earlier APKs and the normal `mockareel-preview.apk` alias are preserved.
