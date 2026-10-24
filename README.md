# Mockareel Android preview

[Download v0.11.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.11.0.apk)

Install over your current preview; signing certificate and application ID are unchanged.

## v0.11.0 — reference home screens

| Classic iPhone | Google Pixel | Samsung One UI |
| --- | --- | --- |
| ![Classic iPhone](home-iphone-0.11.0.png) | ![Pixel](home-pixel-0.11.0.png) | ![One UI](home-oneUi-0.11.0.png) |

- **iPhone:** five-row classic app grid, colorful vector app artwork, centered AM/PM status clock, page dots and translucent labeled dock. The old large dashboard clock/widget is gone.
- **Pixel:** compact date/weather, open wallpaper, folder/app row, five-app dock, bottom search bar and gesture handle.
- **One UI:** weather card, briefing/health pills, search bar, four-column apps, dock and three-button navigation.
- Layouts follow the supplied examples. Wallpapers and icons are original Flutter vector drawings; the reference photos, phone frames and watermarks are not bundled.
- In **Sequence → Home screen & status bar → Home apps & dock**, edit grid and dock labels/icons independently per OS. **Feed launch tile** swaps the feed app into another grid position; opening/closing animation follows the chosen tile. Blank grid labels hide unused slots.
- Weather fields, briefing/health text and iPhone time suffix are editable. Existing customized eight-slot label/icon data is retained and migrated where applicable.
- The icon toggle and **Use media without overlays** action remain available for supplied screenshots/recordings. Original media remains undimmed when mock overlays are disabled.
- Standard Android retains its generic layout. Saved projects and portable backups include the new per-preset settings.

The previews are Flutter renders, not physical-device screenshots. The layouts are inspired by the supplied home-screen examples and remain editable mockups.

Source: `a3821577f9c7bcd35556cd13a88a9b08ae77ba47` on `main` and `work` (feature commit `73cf52b`).

Validation: 55 Flutter tests, five Kotlin tests and five release-metadata tests; formatting/analysis clean; visual review of all three presets; Android release build; signature, ZIP integrity and 16 KB alignment checks; no credential-pattern matches in the APK. Tests include legacy-data migration, independent grid/dock settings, launch-target swapping, portable backup restoration, screenshot pixels and actual export UI frame capture. Native encoding still needs physical-device verification.

SHA-256: `2bd79d452b68453d4f1241f2b8473a0fcb205944a4e8fdf75fe8f24c7a2187ca`

Earlier versioned APKs and preview images remain available on this branch.
