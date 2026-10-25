# Maps WebView proof of concept · search and headers

Branch: `poc/maps-webview-search`. This branch uses application ID `dev.mockareel.mockareel.mapspoc` and launcher name **Mockareel Maps POC**, so the test APK installs alongside normal Mockareel with separate project storage. This is not a production release or a change to `main`. Export/import `.mockareel` backups to move projects between the normal app and this separate test app.

## Try it

1. Open **Mockareel Maps POC**, create a Maps place story and select **Find a place on Google Maps**.
2. Search for a place and city, such as `coffee shops Subic Bay Freeport Zone`, or paste a Google Maps HTTPS share link.
3. Choose a native result card. Wait for its place details, optionally select a featured review, then tap **Use this place**.
4. The editor receives editable name, category, rating, review count, address, phone, website and opening-hours text when Google exposes them. Selected review text, author and rating populate the optional featured review. Unknown values stay blank. Exact target coordinates and an official Places ID are retained when present; a map viewport is never treated as the business location.
5. Under **Place → Header**, tap **Load Google map**. The saved listing opens in a framing screen without an API key. Pan/zoom, wait for visible tiles, then choose **Use map header**. The PNG is stored in project media and used by preview, PNG/MP4 export and portable backups. You can still upload a map image or choose a photo header.
6. **More project options → Advanced · Google Maps** keeps an optional API key and **Use API map headers** switch. Browser mode remains the default even when a key is saved. The settings enumerate the required APIs; see [API setup](google-maps.md).

If Google shows a consent/interstitial page, use **Show browser**, complete the interaction yourself and select **Read page**. This does not implement Google sign-in. **Use API lookup** remains available in the search page's menu, and manual editing is always available in the editor. **Refresh place details** can pick up fields that arrived after the initial snapshot.

## How it works

The native search UI sits over an attached 1000×800 logical-pixel WebView. The browser has a real viewport and JavaScript enabled; it is not given zero dimensions, detached, or wrapped in an offstage widget. Desktop-site mode keeps Google Maps on the website instead of handing navigation to the Maps application. Google Maps pages are requested in English so the DOM labels remain predictable, including after short-link redirects.

Search is submitted explicitly, not on every keystroke. The importer reads the currently loaded cards (up to 15), then loads only the selected listing. The shared `assets/maps_dom.js` extracts bounded JSON from the DOM. A 35-second timeout, document readiness, a short stability check, cancellation tokens and a native operation guard avoid infinite waits and stale results. Closing the search navigates the WebView to a blank document.

Only Google Maps/consent HTTPS navigation is allowed, plus the internal blank document. External app, file and script URL schemes are rejected. Normal TLS verification is retained. There is no API key, backend browser or native JavaScript message bridge for this lookup, and WebView cookies are not included in project backups. No browser data is logged by app code.

Results and review visibility vary with Google layout, locale and browser conditions; selectors are not a stable API. Review excerpts may be truncated on the source page. Fields and inferred button choices remain editable. This POC targets Android; physical-device/WebView behavior must be checked separately from a desktop-browser DOM test.

## Header capture

The header uses a visible, hybrid-composited Android WebView with a fixed 1000×625 desktop viewport, fitted to the framing area. The shared `assets/maps_header.js` collapses the listing panel and removes search/account chrome while retaining Google branding, map labels and attribution. It waits for a visible map canvas and footer over several samples, with a 35-second timeout. Check that tiles have loaded before saving; DOM readiness is not proof that every tile has finished.

Android `PixelCopy` copies just this viewport from the window, including GPU map layers. The Flutter framing page brings it fully into view, locks interaction for capture, and sends bounded physical-pixel coordinates to a Flutter-only method channel. PNG encoding runs off the UI thread; there is no JavaScript-to-native capture bridge. This path requires Android 8/API 26 or newer. The map URL is retained in the place model so reloading opens the same listing. Older projects fall back to their place name/address or exact coordinates.

The story header reveals a single continuous map behind the moving place sheet, aligned to the bottom so original branding and attribution remain visible. The framing screen outlines the lower area that remains visible after the intro; keep the place inside it. The guide is hidden before capture. Existing headers can be reframed if their marker lies outside that final area. The saved PNG remains unchanged. Browser framing zoom/pan are captured in this image; re-opening the framing screen returns to the original listing rather than restoring the previous pan. The numeric map-zoom slider applies to optional API headers only.

Physical Android capture still needs device verification; browser rendering and native compilation do not validate `PixelCopy` on a phone. Upload/API alternatives remain available if a device cannot capture the map.

## Validation

`flutter test` covers URL restrictions, target-versus-viewport coordinates, Places IDs, category-based button defaults, WebView JSON encoding, native selection/review import, cancellation and stale completion, and short/landscape layouts. Existing editor/export checks also run.

The exact JS asset can be evaluated by Playwright for a live search → result → details check. Browser research artifacts stay outside the repository; no downloaded Google HTML, Google frontend keys, real review fixtures or private shared coordinates are committed.

Build the branch with `bash tool/build_android.sh`, or the pinned Actions debug workflow. The branch-specific package verifier expects the separate POC application ID. All builds and Flutter/native tests run sequentially because generated plugin registration is shared.

GIFs now play as animation in preview and export. Timing controls select the start offset and duration, with an optional loop toggle. Existing GIF photos are detected automatically. Selected frames become a cached MP4 shared by preview and both export templates; original GIFs remain in projects and backups. See [GIF timing and caching](gifs.md).
