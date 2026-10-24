# Mockareel Android preview

[Download v0.9.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.9.0.apk)

Install over the previous preview using the same development signing key. Saved projects and device settings are preserved.

## v0.9.0 — project library and TikTok-style FYP scroll

- The app opens to a thumbnail grid of saved projects. New project opens a template gallery with Maps place story and TikTok FYP scroll. Editor back arrows return to the library and save changes.
- FYP sequence: typed search and loading → first post → timed vertical swipes → optional app close to a home screen. Alternatively start with a home-screen app launch or directly in the feed. Empty search skips the search scene.
- Every post has its own username, profile image, title, caption, sound label, verification/following state and engagement counts. Duration, video trim, crop, zoom, reorder and removal controls are available per post.
- Home screen: photo/video wallpaper, editable time/date, optional widget/status bar, widget text and eight editable app labels/icon presets. Short video wallpapers loop. Launch/close animates a still of the first/last post.
- Four suggested editor steps: Sequence → Posts → Audio (optional) → Export. Pinned preview, expandable canvas and focused inspectors follow the existing charcoal/violet workspace.
- Android MP4 export uses native moving video textures, animated UI surfaces and optional background music. Source video audio stays muted. Outgoing videos hold their final frame during swipes; incoming videos play.
- Autosave and portable backups include avatars, home media, post metadata and sequence settings. Existing Maps projects remain supported.

[Project library](library-0.9.0.png) · [Template gallery](templates-0.9.0.png) · [Post output](post-0.9.0.png) · [Home screen](home-0.9.0.png) · [Post editor](editor-posts-0.9.0.png)

Screenshots are Flutter renders with illustrative media cropped from the supplied reference recording, not physical-device captures.

Source: `9b91b115623ec11de0a92e47e1d7881bc307b7b8` on `work`.

Validation: clean static analysis, 39 Flutter tests, five Kotlin motion/clock tests, visual review and release APK signature/archive/alignment checks. Tests exercise actual export UI frame capture (typed search, transparent video regions, outgoing post and animated closing), scene boundaries, library/editor navigation, saved independent post data, backup media and Maps regressions. Native MP4 encoding still needs physical-device verification; device integration coverage is included in source.

SHA-256: `fed2a94c83aa6fa7d70bc0490a0619b19da84f3d9be496273444df3c9b15ed62`

Earlier versioned APKs and previews remain available on this branch.
