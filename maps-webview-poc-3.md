# Maps WebView POC 3 · continuous map header and GIF export fix

[Download test APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-maps-webview-poc-3.apk) · [SHA-256](mockareel-maps-webview-poc-3.apk.sha256)

Updates **Mockareel Maps POC** in place, retaining its existing project storage. Package `dev.mockareel.mockareel.mapspoc`, version `0.13.0-maps-poc.3+19`, development signing identity unchanged. Normal Mockareel and its preview APK alias are unchanged. No Google API key is embedded.

Source: [poc/maps-webview-search](https://github.com/jc-tanedo/mockareel/tree/poc/maps-webview-search), commit `a9f2cbeffd2945479bdf2824712ef3cd3c9abeb0`. No merge to stable `main` or `work`.

## Fixes

- **Map header:** removed the duplicated map/footer layer that produced a horizontal cut during the intro. A single continuous map is revealed behind the moving place sheet, with bottom alignment retaining the original Google branding and attribution. The framing screen now marks the lower area that remains visible after the intro. If an existing header's marker falls above that area, use **Place → Header → Load Google map** to reframe it. Keep the marker below the guide line. The guide disappears before capture and is not saved in the map image.
- **Export:** Media3 rejects `image/gif` photo inputs. Both Maps and FYP export now recognize GIF file signatures, even with misleading filename extensions, and send a temporary PNG first frame as the source and posters. Original media/project paths are untouched; temporary conversions are cleaned up after success, failure or cancellation. Other photo formats and video clips retain their existing paths.

**GIF animation is not exported in this build:** GIF photo clips become still first frames. Use MP4 for animated content in the output.

## Try it

1. Open the project that failed and retry **Render MP4**. GIF photos no longer reach the encoder as `image/gif`.
2. Scrub the opening reveal and check that the map has no duplicated strip. Existing map images still load; reframe if the place is outside the highlighted final header area.
3. Optional API access remains under **Advanced · Google Maps**. Browser search/header capture still need no API key.

## Validation

74 Flutter tests, five Kotlin tests, five release-metadata tests, formatting and Dart analysis passed. New tests decode a real two-frame GIF stored with a JPEG filename, verify its PNG first-frame pixels and original-file preservation, check both templates' native export arguments and cleanup on export failure, and inspect map pixels at three intro heights to catch the duplicated strip. Existing export/editor tests pass.

The APK passed signature/package/version, ZIP integrity, 16 KB alignment and credential-pattern checks. Device video encoding still needs a retry on the affected phone; automated renderer tests verify the encoder inputs rather than performing a physical-device Media3 encode.

SHA-256: `0c8aea46edbe519cb65f24571089c6b06770cdb81a47abd8883476394f6ae044`.

[Previous POC 2](maps-webview-poc-2.md) · [POC 1](maps-webview-poc-1.md). Previous APKs are preserved.
