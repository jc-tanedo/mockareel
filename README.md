# Mockareel Android preview

[Download v0.4.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.4.0.apk)

Install over the previous preview; it uses the same development signing key.

## v0.4.0

- Place buttons suggested from Google place types and available phone/website, with editable labels/icons, add/remove, Menu visibility and footer controls.
- Device background music with volume, start offset and looping; synchronized preview and AAC soundtrack export.
- Multiple movable text layers with story-style editing, colors, styles, size, rotation, duplication and deletion. Existing badges migrate to editable tags.
- Charcoal/violet editor with focused Place, Timeline, Text, Audio and Export sections, a thumbnail strip and selected-clip inspector.
- Music and text are included in autosave and portable project backups.

Source: `080c222c7c1f771af8a547dba3f6f0c509abc150` on `work`.

Validation: static analysis clean, 19 Flutter tests, 2 native motion tests, editor screenshot review, release build and APK integrity/signature checks. Native soundtrack playback and encoding still need a physical-device check; cloud emulator services are unstable.

SHA-256: `20851388e9991bb3219b9de8718d55a1395e0f0c474c7dc7021dded0ca765d20`

[Timeline screenshot](editor-timeline-0.4.0.png) · [Text screenshot](editor-text-0.4.0.png)

Earlier versioned APKs remain available on this branch.
