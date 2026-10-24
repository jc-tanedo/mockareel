# Mockareel Android preview

[Download v0.11.1 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.11.1.apk)

Install over your current preview; signing certificate and application ID are unchanged.

## v0.11.1 — smooth video swipes and visible removal

- The incoming feed video keeps its player when a swipe finishes. Removing the outgoing post no longer recreates the video decoder and causes a preview flicker.
- **Posts → Remove post** is always visible beside the selected-post dropdown, across Identity, Caption, Stats and Timing & frame. **Undo** restores the removed post and its edits.
- Removal and Undo autosave; fields refresh for the remaining selected post. Removing the final post shows a scrollable empty state on short screens.

Source: `c51614ee978b55d7355a30d15aacc1c41dabfdfa` on `main` and `work`.

Validation: 57 Flutter tests, five Kotlin tests and five release-metadata tests; formatting and analysis clean. The video regression reproduced a second player being created after a swipe before the fix, and now verifies the same player stays active across two successive swipes with trim applied. Removal tests cover all tools, autosave, Undo, field refresh and the final post. APK signature, package/version, ZIP integrity, 16 KB alignment and credential-pattern checks passed. Preview playback was tested with a fake video platform; physical-device playback and native encoding were not run for this update.

SHA-256: `26b9b56b1f5d18262f5836773a60173b308fe9ed7e653d1d7aff27e67b7d72a1`

## Reference home screens

| Classic iPhone | Google Pixel | Samsung One UI |
| --- | --- | --- |
| ![Classic iPhone](home-iphone-0.11.0.png) | ![Pixel](home-pixel-0.11.0.png) | ![One UI](home-oneUi-0.11.0.png) |

These are Flutter renders of the existing v0.11.0 home-screen layouts, with original vector icons and wallpapers. Grid/dock labels, icons and launch position are editable independently per OS.

Earlier versioned APKs and preview images remain available on this branch.
