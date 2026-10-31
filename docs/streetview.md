# Streetview journey

Choose **Streetview journey** in the template gallery. Add photos, videos or
supported GIFs in Timeline. In Place, select each media item, find its location
using the existing key-free Maps browser, and capture the map. Place name,
address, category, rating and suggested action buttons remain editable.
The capture button appears only after a Maps search result has been selected for that media.
Map captures are project assets; preview and export use the saved image offline.
Saved map images are fitted in full, including their added attribution footer.
Map capture always uses a 1440-pixel-wide inner map with 240 extra CSS pixels on
every edge. The editor and capture show only the centre, cropping out native
browser controls. Footer layout never disables cropping or blocks tile readiness.
Enter attribution in **Map / imagery credits** below the framing view. The app
stamps **Google Maps** and your entered credits onto the PNG after capture;
preview, export and backups use that same saved asset. Credits are not extracted
from the WebView. Use **Replace captured map** once for older images containing
native controls, since those controls are already baked into their PNGs.

The opening map uses the first media's location and thumbnail. Choose
**Transition to next media** independently for each media item:

- **Arrow movement:** select left or right and set the movement duration.
  The selected arrow receives a tap ripple, then the outgoing final frame blends
  into the destination's first frame with directional movement and blur.
- **Return to Maps:** the back control receives a tap ripple, then the next
  media's map appears. Its thumbnail receives a tap ripple and cuts directly
  into the media. There is no animated geographic travel or entry zoom.

Reordering moves the location, map, overlay options and transition with the
media. Removing an item automatically changes the preceding transition's
destination. The opening thumbnail always follows the first item.

## Timing

The default opening map is 2 seconds, later maps 1.5 seconds, and transitions
0.45 seconds. Map and transition durations are adjustable. Media duration,
trim, GIF looping and framing use the shared editor controls. Transition time
is added to the total rather than taken from a media segment.

Tap ripples last 0.2 seconds. A map's thumbnail ripple occupies its final
0.2 seconds; an arrow ripple occupies the first 0.2 seconds of the movement
transition. The back-control ripple occupies the final 0.2 seconds of its
transition. Each ripple is included in its containing scene exactly once.
The optional ending adds a back-control transition and a final map hold, with
no thumbnail tap to reenter Street View. By default the output ends on media.

Use the **Camera motion** card to enable slow zoom, horizontal pan and a simulated
turntable independently for each item. Adjust zoom amount, signed pan distance
and signed turn angle (up to 15°). Turntable applies a gentle perspective yaw to
ordinary media. All three motions carry the navigation arrows with the scene;
the toolbar and place sheet stay fixed. Default zoom/pan amounts are 6% and eight
logical pixels. The camera slightly overscans the source to keep edges filled.
Place sheet, top controls and navigation arrows can be hidden separately.
Output theme and background music use the shared controls.

The interface follows the updated references: Maps has a rounded search bar,
nearby pill, layer/location controls and a small Street View thumbnail above a
collapsed place sheet. Street View has a Google/date pill, overflow and close
circles, perspective ground chevrons, an editable Aerial badge and an expand
control. Both use a rounded place sheet with teal action buttons. New Streetview
projects default to dark output; existing theme choices are retained. Phone
chrome, Messenger and video-player controls are excluded. Captured map colors
come from the selected map; output theme changes the interface, not map pixels.

## Media effects

Use the **Media effects** card for the selected media in Place or Timeline → Motion.
Enable **Lens effect**, choose **Fisheye** or **Pincushion**, and adjust its
strength from 0–100%. For photos, use **Add blur spot** to
create up to eight feathered circular spots. Drag a circle on the source preview,
select a numbered spot to edit it, adjust its size, or remove the selected spot.
Spot handles have a minimum 64-pixel touch target, independent of blur size.
A 2× magnifier appears above your finger while dragging, with a crosshair showing
the landing point. Near the top of the screen it moves below your finger to stay
visible. It disappears on release or cancellation. Spots stay at their chosen position throughout that media segment. Videos and
GIFs support lens effects only; any older blur recipes on timed media are ignored.

These are non-destructive source edits. Lens effects and spot blur run before template
framing, camera motion and interface composition. Maps and UI are never warped
or blurred. The same processed source supplies playback, thumbnails, transition
frames and export. Changes are coalesced and processed asynchronously; the
source editor shows progress while an updated preview is being prepared.

Projects and portable backups keep the originals and the edit recipes. Temporary
processed PNG/MP4 assets are cached locally and can be regenerated offline.
Video trimming and GIF looping occur once, and motion remains video throughout.
GIF preparation, source processing and final export share one encoder queue for
Android devices with only one hardware encoder.

## Implementation and validation

`StreetviewTimeline` describes every map, media and transition scene. The same
scene plan drives scrubbing, live playback and export capture. Video/GIF players
are retained and preloaded across scene boundaries, pause with preview and stop
at the exact end. During arrow transitions, still end/start frames supply the
movement effect; normal media segments retain native video/GIF motion.

MP4 export reuses the existing Android full-screen texture compositor and shared
progress, cancellation, gallery and music handling. Only map/UI/transition frames
are rasterized; ordinary media segments remain native textures. Backups include
all map assets and deduplicate repeated map paths, restoring them through the
existing bounded archive importer. Existing version-2 Maps/TikTok projects retain
their identifiers and duration rules.

Host tests cover timing, JSON compatibility, backup map retention/deduplication,
destination thumbnails, player reuse, exact-end pause and transparent UI capture.
Android device checks are still required for live Maps interaction, hardware
codecs and visual comparison of exported MP4s. Interactive panoramas and animated
travel between pins remain outside this template.

For an optional Linux GPU smoke check using headless Mesa EGL (no extra Python
packages), run `python3 tool/check_media_shader.py`. It compiles and executes the
production GLSL and checks zero-strength identity, opposite lens distortion, isolated
spot blur and the editor’s top-left coordinate convention. This complements the
native tests; it does not replace hardware codec testing on Android.

With Python Playwright, Pillow and system Chromium installed, run
`python3 tool/check_maps_header.py` for the offline browser fixture. It checks
that initial and late-added map controls are hidden, external zoom still works,
and map labels and pins remain visible. Separate PNG tests verify the manually added attribution.
