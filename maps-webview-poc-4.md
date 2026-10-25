# Maps WebView POC 4 · animated GIF timing and export

[Download test APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-maps-webview-poc-4.apk) · [SHA-256](mockareel-maps-webview-poc-4.apk.sha256)

Updates **Mockareel Maps POC** in place, preserving projects. Package `dev.mockareel.mockareel.mapspoc`, version `0.13.0-maps-poc.4+20`, same development signing identity. Normal Mockareel and its APK alias are unchanged. No Google API key is embedded.

Source: [poc/maps-webview-search](https://github.com/jc-tanedo/mockareel/tree/poc/maps-webview-search), commit `ba7d2d72e5c9ee1fccda5944a1958e42a31e793c`. No merge to stable `main` or `work`.

## Try it

1. Open your existing GIF project. GIFs previously treated as photos are detected automatically, even when the filename ends in `.jpg`.
2. Select a GIF and open **Timing** in Maps, or **Timing & frame** in FYP.
3. Choose duration and start offset. **Loop GIF**, enabled by default, repeats the source cycle from that starting phase to fill the clip. Turn it off for a single source segment. GIF durations shorter than half a second are supported.
4. Preview, pause and scrub, then export normally. GIFs now animate in both preview and output. Optional GIF home-screen media also follows the existing wallpaper repeat flow.

The first preparation may take a moment. A selected GIF segment is decoded into the frames actually sampled by the 30 fps output timeline, with variable GIF delays preserved at that rate. Earlier delta frames are decoded when needed for compositing/disposal, but only selected frames are retained. Loops reuse those frame images. Android Media3 encodes a single timestamped overlay timeline to a cached MP4; preview and export reuse it while source/timing/loop settings match.

Original GIF files stay in project media and backups, along with editable timing/loop settings. Cached videos are not backed up and may be regenerated. Temporary PNG frames and partial MP4s are cleaned up on success, failure and cancellation. Cache requests snapshot the editor's timing before asynchronous work, so rapid timing changes cannot place the wrong segment under a cache key. Early cancellation also prevents queued encodes from starting.

This replaces POC 3's first-frame-only GIF compatibility path. The continuous map-header and framing-guide fixes from POC 3 remain included. Browser Maps search/header capture still need no API key; optional API access remains under **Advanced · Google Maps**.

## Validation and limits

81 Flutter tests, six Kotlin tests, five release-metadata tests, formatting and Dart analysis passed. Coverage includes variable frame delays, trim/loop boundaries, decoded selected-frame pixels, omitted earlier PNGs, cache reuse/invalidation, in-flight timing mutation, cancellation before/after encoding starts, cleanup, both templates' native video/poster arguments, GIF preview seek/reload behavior, and existing-project detection/backup round-tripping. APK signature/package/version, ZIP integrity, 16 KB alignment and credential-pattern checks passed.

**Hardware GIF-to-MP4 encoding still needs a test on the target phone.** Desktop tests verify frame pixels, timing, playback contracts and encoder inputs; they do not claim to execute Android codecs. GIF transparency is flattened against black, and frames are resized to at most 1080 pixels per side. Limits include 64 MiB input GIFs, 2,000 source frames, 32 megapixel source canvases and 256 MiB of retained frame PNGs per preparation. See the [GIF guide](https://github.com/jc-tanedo/mockareel/blob/poc/maps-webview-search/docs/gifs.md).

SHA-256: `dd4a2b27ba57be6c74cdddc6d3796ddfa98cf4de11e1b1d4b1815988f8ad381b`.

[Previous POC 3](maps-webview-poc-3.md) · [POC 2](maps-webview-poc-2.md) · [POC 1](maps-webview-poc-1.md). Previous APKs are preserved.
