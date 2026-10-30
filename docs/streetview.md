# Streetview journey

Choose **Streetview journey** in the template gallery. Add photos, videos or
supported GIFs in Timeline. In Place, select each media item, find its location
using the existing key-free Maps browser, and capture the map. Place name,
address, category, rating and suggested action buttons remain editable.
Map captures are project assets; preview and export use the saved image offline.
The captured image is fitted in full to preserve its source attribution.

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

Slow pan/zoom applies a gentle 6% zoom and eight logical pixels of horizontal
movement over a media segment. It can be enabled independently for each item.
Location/date card, top controls and navigation arrows can be hidden separately.
Output theme and background music use the shared controls.

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
