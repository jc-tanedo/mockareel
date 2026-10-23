# Mockareel Android preview 0.2.0

[Download Mockareel 0.2.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.2.0.apk)

Sign into GitHub with repository access before downloading. Install over the previous preview; the signing certificate is unchanged and version code is 2.

Implemented: editable place details with Google Places lookup; photo/video import into durable app storage; dynamic timeline, per-clip duration, video trim starts, captions and reordering; playback/scrubbing; native silent 720×1280 MP4 rendering, playback, sharing and gallery saving; autosaved projects and portable backups containing media.

The running cloud environment did not expose a Maps API key. Enter a key for **Places API (New)** via the app's Settings button to use search. Manual place editing and MP4 rendering require no key.

`flutter analyze`, all eight unit/widget tests and the release build pass. Signature and 16 KB alignment checks pass. The device integration test could not start because Android system services crashed in the unaccelerated cloud emulator during installation. Native media picking/playback, MP4 encoding and gallery saving remain unverified on a device. This is a development build, not a fully verified release.

Exports are silent and use cuts with a gentle photo zoom. Exact matching of the original video and its animated scrolling transition remain unfinished; the original attachment is no longer available in the current workspace.

Source commit: `d02a39cd2b3894625397bac797d2b3cfc64e27db` (branch `work`).

SHA-256: `7aaec34b50a1691d640287af18cb21cf119aad85236168df198b31d79a9b4c7d`
