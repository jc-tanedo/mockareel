# Maps place story reference

Reference: `received_1105996848693739.mp4`, 576×1296, 30 fps, 29.067 seconds. The recording includes editor controls, scrolling of the editor itself, and a floating assistant button. The template's export panel explicitly specifies a 1080×1920 9:16 reel and a transparent PNG cutout.

## Layout

The shared logical canvas is 360×640, rasterized at 3× for export. A hero photo peeks behind a white sheet beginning around y=94. The place name, alternate name, rating/review count, category/price, hours and four teal action chips remain fixed. An optional story badge and decorative story controls reproduce the corresponding switches in the reference.

The gallery occupies `(16,250)–(344,500)`: 328×250 logical pixels. Cards have rounded 12-pixel corners and 8-pixel gaps. Width stays at or below the viewport width so a focused card can always be shown completely; shorter cards center vertically. Overview/Menu/Reviews/Photos/Updates, Order online and the hours footer stay below the gallery.

Card framing controls are width, height, zoom and horizontal crop. A selected media item can supply the peeking header photo independently of which gallery card is in focus.

## Motion

At each card boundary, scroll offset moves from the preceding card's start to the new card's start using ease-out cubic. It then remains at that exact offset for the hold. Entry duration defaults to 0.42 seconds and is capped to 45% of a short card's total duration. There is no extra transition time added to the timeline. The reference-pace preset uses 1.56 seconds per card and a 0.35-second entry, giving five cards 7.8 seconds overall.

Flutter preview and the Android compositor share the layout parameters. The native compositor positions the active video texture, draws the other visible cards from cached start/end stills, masks rounded edges and gallery bounds, then overlays the same UI PNG rasterized by Flutter. Native frame timestamps are normalized to each item's first decoded frame to accommodate trimmed videos and concatenation.

## Checks

Render tests compare fixed header/footer pixels across first/moving/held frames, inspect card colors and rounded corners, check horizontal crop direction, and verify PNG alpha. An app-level test invokes both PNG export buttons and inspects their shared 1080×1920 files. Host Kotlin tests check the equivalent native motion positions and timestamp normalization. Codec execution and native gallery saving still require a physical Android test; the included emulator could not keep its Android system services running long enough to install the test build.
