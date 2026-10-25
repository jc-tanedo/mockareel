# Animated GIFs

[← User guide](user-guide.md)

GIFs work as animated media in Maps galleries, FYP posts and optional home-screen media. Import them with the normal media picker. Existing GIF photos in saved projects are detected automatically, including GIF content saved with a `.jpg` name. Project originals remain GIFs.

## Timing

Select the clip and open **Timing** (Maps) or **Timing & frame** (FYP):

- **Duration** selects how long this clip appears in the reel, up to 30 seconds.
- **Start / Trim start** selects the source offset.
- **Loop GIF**, enabled by default, repeats the source cycle from that starting phase until the clip duration is filled. Turn it off to select one continuous source portion; duration and start are then constrained to the available source.

Scrubbing and pausing use the selected segment's video clock. A timing change prepares a new segment after a short debounce. Frame delays are preserved on the app's 30 fps output clock; extremely short source frames are sampled accordingly. Zero/10 ms GIF delays follow common browser behavior (100 ms).

## Preparation and cache

Flutter decodes the earlier frames required to reconstruct GIF delta frames and disposal, but retains only frames sampled by the selected segment. Repeated samples and loops reuse PNGs. Android Media3 encodes one timestamped overlay timeline into a cached H.264 clip, avoiding a new asset-loader start for every GIF frame. Preview, outgoing/start/end posters and final video export use the selected segment consistently.

The prepared MP4 is reused by preview and export while source/timing/loop settings match. Cache entries include source path, size and modification time; segments publish atomically after successful encoding. Old cached clips may be evicted and prepared again. Cache media is excluded from project backups; the original GIF and editable timing are included.

Temporary frame PNGs and partial MP4s are removed on completion, failure or cancellation. Decode jobs and native preparation are serialized to avoid spawning an encoder per thumbnail. Limits include 64 MiB input files, 2,000 source frames, 32 megapixel source canvases and 256 MiB of retained frame PNGs per preparation. Prepared frames are resized to at most 1080 pixels per side. GIF transparency is flattened against black in the cached video. The Android video renderer remains the export target.

Device testing has confirmed animated GIF preview and Media3 export. Automated tests cover the native timing selector and Dart frame extraction/cache/preview contracts, including late playback commands and end-of-reel pause. Desktop widget tests use a mocked encoder; codec behavior can still vary by device.
