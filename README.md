# Mockareel Android preview

[Download v0.8.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.8.0.apk)

Install over your previous preview using the same development signing key.

## v0.8.0 — guided editor workspace

- Five suggested, numbered steps: Place → Timeline → Text (optional) → Audio (optional) → Export. A Next action guides the sequence; all steps remain freely accessible.
- Pinned preview and separate scrolling inspector, expandable preview, restart control, and a side-by-side layout on wide screens. Keyboard entry gets the inspector workspace.
- Place panels: Details, Look, Header, Buttons, Review. More place metadata is grouped under Details; output theme and decorative story controls are in Look.
- Timeline: persistent thumbnail strip, with Timing, Frame and Motion tools. Compact layouts use a clip selector; thumbnail long-press reveals the filename.
- Text transform controls and music timing/looping are grouped separately from the main actions. Text editing uses a settled canvas for positioning layers.
- Export keeps Render MP4 visible and groups PNG exports under Still images. Missing map-header setup links back to the Header panel.
- Settings, renaming and backups remain in the project menu; the folder and explicit Save actions remain in the header.

[Place](editor-place-0.8.0.png) · [Timeline](editor-timeline-0.8.0.png) · [Framing](editor-framing-0.8.0.png) · [Text](editor-text-0.8.0.png) · [Export](editor-export-0.8.0.png)

Screenshots are Flutter renders using illustrative photos cropped from the supplied reference recording.

Source: `16610096dff189a80cd2d0bb3bf769d586b2f5bd` on `work`.

Validation: static analysis clean, 32 Flutter tests, visual review of all steps and tool panels, release APK built with its signature, archive integrity and alignment checks passing. Tests include optional-step skipping, accessible step actions, pinned/expanded previews, keyboard edits, short-phone and landscape layouts, saved edits and actual PNG export/share flows. Native encoding still needs physical-device verification.

SHA-256: `7f1b40fb9916b1617031a62e634566cb75a0a5681f21fb7eb5e2ec34c7a707ba`

Earlier versioned APKs and previews remain available on this branch.
