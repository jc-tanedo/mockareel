# Mockareel mark

A circular film reel becomes a fish: four reel perforations, center spindle, forked tail, and a small eye/mouth notch. All holes are true transparent cutouts. No gradient, shadow, outline or wordmark is needed for the glyph.

- `mockareel.svg`: lavender glyph, transparent background, scalable 128×128 viewBox.
- `mockareel-monochrome.svg`: same geometry using `currentColor` for one-color contexts.
- `mockareel-mark.png`: 1024×1024 transparent glyph.
- `mockareel-icon.png`: 1024×1024 lavender-on-charcoal app icon.
- `icon-preview.png`: launcher and monochrome mark, 24/32/48/64-pixel size checks, circular-mask review.

Colors: lavender `#B1A6FF`, charcoal `#202023`. The Android launcher supplies adaptive background/foreground and Android 13 monochrome layers, plus raster legacy/round icons at 48/72/96/144/192 pixels. The adaptive mark fits the central 66dp safe circle of the 108dp artwork.

The source is `tool/generate_brand_assets_test.dart`. It writes SVG, Android vector and raster assets from the same path geometry:

```sh
source tool/cloud_env.sh
flutter test tool/generate_brand_assets_test.dart
```
