# Mockareel Android preview 0.3.0

[Download Mockareel 0.3.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.3.0.apk)

[View the template preview animation](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/template-preview-0.3.0.gif)

Open while signed into GitHub with repository access. Install over the previous preview: the certificate is unchanged and version code is 3. [Previous 0.2.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.2.0.apk).

This version follows the supplied reference: peeking header photo, fixed Maps-style place details and footer, and rounded media cards scrolling left, snapping fully into view, then holding. Per-card controls include width, height, zoom, horizontal crop, duration, video trim and caption. Template details include review count, price, hours, alternate name, story badge, optional story controls and header-photo choice. The reference-pace preset gives five cards 7.8 seconds.

MP4 output targets silent 1080×1920 video. Transparent cutout and full-snapshot PNG exports are also 1080×1920. Originals, framing and template settings are retained in projects and portable backups. The active video plays while neighboring video cards use cached start/end stills during transitions.

The preview GIF is rendered by the Flutter template code using image crops from your reference recording. It demonstrates layout and motion; it is not a recording of native Android MP4 export.

Verified: analysis, all 14 Flutter tests (including actual PNG export files and alpha), both host Kotlin motion tests, visual rendering, release build, APK signature and 16 KB alignment. **Native execution on a physical Android device remains unverified.** The cloud emulator's Android services crashed before its integration test could run. Codecs, native picker/player, sharing and gallery saving still need device verification.

Google Places lookup uses Places API (New). A key already saved in the app remains available across this update; otherwise enter it via Settings. The environment did not expose a build-time key. Manual editing and rendering do not require a Maps key.

Source: `6e80a94732892fe8e85df9f279726914c5d41110` on branch `work`.

APK SHA-256: `e2e72a7326792507d7601ded1b3ac28ff18f3e2267d9c8aaa04816d429954016`
