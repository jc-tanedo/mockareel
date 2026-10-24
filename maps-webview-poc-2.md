# Maps WebView POC 2 · map headers and advanced API settings

[Download test APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-maps-webview-poc-2.apk) · [SHA-256](mockareel-maps-webview-poc-2.apk.sha256)

Updates the previous **Mockareel Maps POC** installation with the same separate application ID (`dev.mockareel.mockareel.mapspoc`) and development signing identity. The normal app has its own package and data. No Google API key is embedded in this test APK.

Source: [poc/maps-webview-search](https://github.com/jc-tanedo/mockareel/tree/poc/maps-webview-search), commit `c1f0757a9dd34c2a39930b913f202543633dffcf`. Stable `main` and `work` are unchanged.

## Try map headers without a key

1. Open an existing Maps project, or create a **Maps place story** and find a place as in POC 1.
2. Choose **Place → Header → Load Google map**.
3. Wait for the map tiles to appear. Pan or zoom in the framing screen, then choose **Use map header**.
4. Check the saved map in the story preview and export. It is stored in project media and included in portable backups. The location stays centered as the header shrinks, with the original branding/attribution footer retained.

Older POC projects without a saved listing URL fall back to their place name/address. Newly imported places retain their exact listing URL. Reopening the framing screen returns to that listing; previous pan/zoom is retained in the saved PNG, not restored as a live browser camera.

## Optional API access

Open **More project options → Advanced · Google Maps**. A key is optional. Saving a key alone keeps browser header capture as the default. Enable **Use API map headers** to use the automatic static-image path instead; its numeric zoom slider remains available.

- **Places API (New):** enable for **Use API lookup** in the place-search menu.
- **Maps Static API:** enable for API map headers.
- Enable billing for API requests. Maps SDK for Android, Maps JavaScript API and Geocoding API are not required by Mockareel.

The settings and [API setup guide](https://github.com/jc-tanedo/mockareel/blob/poc/maps-webview-search/docs/google-maps.md) explain API restrictions, quotas and on-device key storage. Manual editing, upload/photo headers and export still work without a key.

## Validation and limits

71 Flutter tests, five Kotlin tests, five release-metadata tests, formatting and Dart analysis passed. Regression checks cover URL persistence/fallback restrictions, portrait/landscape framing and capture handoff, optional key clearing, and keeping the centered map and original footer visible in the collapsed header. The bundled framing script passed live anonymous-browser checks on both a beach share link and a café, with map tiles and attribution visually inspected. Staged source and the APK passed credential-pattern scans. APK signature, expected package/version, ZIP integrity and 16 KB alignment were verified.

**The Android PixelCopy capture path still needs physical-device testing.** Native compilation and browser screenshots do not verify its behavior on a phone. It requires Android 8/API 26 or newer, brings the map viewport into view, and encodes its PNG off the UI thread. If capture fails, retry or use upload/API alternatives. Google DOM and rendering can vary; wait for visible map tiles before saving. TLS verification remains enabled.

Version: `0.13.0-maps-poc.2+18`. SHA-256: `5da93c89a8471a0f079378d841b57c1ab4fec01f82d30be90d452d8011c6582c`.

[Previous POC 1 instructions and APK](maps-webview-poc-1.md). Older APKs and images remain available; the normal `mockareel-preview.apk` alias is unchanged.
