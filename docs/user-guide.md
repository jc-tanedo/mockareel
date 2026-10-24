# Using Mockareel

[← README](../README.md)

## Project library

The app opens to a grid of saved projects with previews of their output. **New project** opens the template gallery: choose **Maps place story** or **TikTok FYP scroll**. The editor’s back arrow returns to the library and saves your changes. Import portable backups with the file icon in the library. Existing Maps projects remain available after upgrading.

## TikTok FYP scroll

Four suggested steps use the same pinned-preview workspace and charcoal/violet editor design: **Sequence → Posts → Audio (optional) → Export**.

1. **Sequence:** open with a typed search, a home-screen app launch, or directly in the feed. A blank search skips the search scene. Set typing time, loading time and vertical swipe duration. Optionally close the app back to the home screen.
2. **Home screen & status bar:** choose iPhone (iOS), Android, Google Pixel or Samsung One UI. Classic iPhone uses a five-row grid, centered status-bar clock and translucent labeled dock; Pixel uses compact date/weather, folders, a five-icon dock and bottom search; One UI uses grouped widgets, a search bar and four-column icons. Choose a photo/video wallpaper, edit time/date and widget text, and customize eight app labels and icon presets. **Show mock app icons** toggles the grid, dock and launcher navigation without discarding labels. Clock/date, widget and status bar have independent switches. When media is present, **Use media without overlays** hides all generated home chrome and removes its dimming, so a supplied screenshot displays without duplicate icons or widgets. Under **Home apps & dock**, edit grid/dock labels and icons, hide unused grid slots with a blank label, and choose the **Feed launch tile**. Moving it swaps tiles and moves the animation target. Standard Android retains its original eight-slot controls. Home hold duration is editable; short video wallpapers loop. The app launch/close animation uses a still of the first/last post.
3. **Posts:** add photos/videos; each becomes a full-screen post. Select a post and use **Identity** (username, profile photo, verification/following), **Caption** (title, caption/hashtags, sound label), **Stats** (likes, comments, saves, shares), or **Timing & frame** (duration, trim, zoom, horizontal crop, reorder/remove). Sidebar and post text slide upward with each post; navigation stays fixed. The outgoing video holds its last frame during a swipe while the incoming video plays.
4. **Audio:** select actual background music, volume, start offset and looping. The per-post sound label is decorative. Source video audio is muted.
5. **Export:** render a 1080×1920, 30 fps H.264 MP4, with AAC when music is present; share or save it to the gallery. The native renderer retains moving video textures and composites UI frames during typing, loading, swipes, launch and close.

Autosave and `.mockareel` backups include all per-post fields, avatars, home media, sequence settings and music. No account or network connection is needed for this template. These are editable visual mockups; the buttons do not navigate to live social profiles.


## First template: Maps place story

The template follows the supplied screen recording: a map header (or optional photo), a white place sheet with editable details and teal action chips, and a horizontal gallery of rounded cards that scrolls left, snaps a card fully into view, then holds. Tabs, a place-specific footer button and hours stay fixed beneath the gallery. Movable text layers and decorative story controls can be added. The editor uses charcoal panels, violet selection highlights and a thumbnail timeline with a selected-clip inspector.

The editor follows five suggested steps: **Place → Timeline → Text (optional) → Audio (optional) → Export**. Numbered navigation and a **Next** action make the sequence explicit; every step remains freely accessible. A pinned preview sits above a focused inspector; expand the preview for a larger view. On wider screens, preview and inspector sit side by side. When typing, the inspector gets the workspace.

1. **Place → Details:** find a Google place or edit its name, category and address. **More place details** holds rating, local name, review count, price and hours.
2. **Place → Look:** choose the output's Light/Dark theme and optional decorative story controls. This setting is independent of the editor's appearance.
3. **Place → Header:** use a Google map, upload a map image or choose a header photo. Set zoom and load again to refresh. New projects use Map; older projects retain their previous header.
4. **Place → Buttons / Review:** customize suggested actions, footer and Menu visibility, or add an optional featured review. A blank or disabled review stays hidden.
5. **Timeline:** add photos/videos and select a thumbnail. **Timing** holds duration, video trim, caption and reorder controls; **Frame** holds card width/height, zoom and crop; **Motion** holds opening reveal, slide speed and reference pacing. Original media is copied into app storage. Small screens use a compact clip selector. Long-press thumbnails to see filenames.
6. **Text:** add movable text layers, tap a layer to style it, duplicate or delete it. Size, rotation and centering are under **Transform**.
7. **Audio:** choose device music and adjust volume. **Timing & loop** holds the start offset and looping controls. Preview playback and scrubbing follow the reel clock. Original clip audio stays muted; skip this step for silent output.
8. **Export:** review format and duration, then use the pinned **Render MP4** action. A missing map header links back to its setup panel. **Still images** holds transparent-template and full-snapshot PNG exports. MP4 is 1080×1920 H.264 with AAC when music is present; PNGs are 1080×1920 with real gallery alpha for the cutout.
9. The project title opens renaming; the back arrow returns to saved projects. **More project options** includes Maps API settings, rename and portable backups. Projects autosave; explicit Save remains in the header.

Projects autosave, including when leaving the app. The library opens and creates projects. Portable `.mockareel` backups include originals, timings, framing, captions, header selection, music, text layers, map image, opening animation, featured review and output theme; they can be imported on another device. Older projects open with default framing.
