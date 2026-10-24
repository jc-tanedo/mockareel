# Maps WebView search proof of concept

Branch: `poc/maps-webview-search`. This branch uses application ID `dev.mockareel.mockareel.mapspoc` and launcher name **Mockareel Maps POC**, so the test APK installs alongside normal Mockareel with separate project storage. This is not a production release or a change to `main`. Export/import `.mockareel` backups to move projects between the normal app and this separate test app.

## Try it

1. Open **Mockareel Maps POC**, create a Maps place story and select **Find a place on Google Maps**.
2. Search for a place and city, such as `coffee shops Subic Bay Freeport Zone`, or paste a Google Maps HTTPS share link.
3. Choose a native result card. Wait for its place details, optionally select a featured review, then tap **Use this place**.
4. The editor receives editable name, category, rating, review count, address, phone, website and opening-hours text when Google exposes them. Selected review text, author and rating populate the optional featured review. Unknown values stay blank. Exact target coordinates and an official Places ID are retained when present; a map viewport is never treated as the business location.
5. Add media and edit/export normally. For an API-free header, upload a map image under **Place → Header**, or choose a photo header. Automatic browser map-image capture is outside this first POC; **Load Google map** still uses the optional API key.

If Google shows a consent/interstitial page, use **Show browser**, complete the interaction yourself and select **Read page**. This does not implement Google sign-in. **Use API lookup** remains available in the search page's menu, and manual editing is always available in the editor. **Refresh place details** can pick up fields that arrived after the initial snapshot.

## How it works

The native search UI sits over an attached 1000×800 logical-pixel WebView. The browser has a real viewport and JavaScript enabled; it is not given zero dimensions, detached, or wrapped in an offstage widget. Desktop-site mode keeps Google Maps on the website instead of handing navigation to the Maps application. Google Maps pages are requested in English so the DOM labels remain predictable, including after short-link redirects.

Search is submitted explicitly, not on every keystroke. The importer reads the currently loaded cards (up to 15), then loads only the selected listing. The shared `assets/maps_dom.js` extracts bounded JSON from the DOM. A 35-second timeout, document readiness, a short stability check, cancellation tokens and a native operation guard avoid infinite waits and stale results. Closing the search navigates the WebView to a blank document.

Only Google Maps/consent HTTPS navigation is allowed, plus the internal blank document. External app, file and script URL schemes are rejected. Normal TLS verification is retained. There is no API key, backend browser or native JavaScript message bridge for this lookup, and WebView cookies are not included in project backups. No browser data is logged by app code.

Results and review visibility vary with Google layout, locale and browser conditions; selectors are not a stable API. Review excerpts may be truncated on the source page. Fields and inferred button choices remain editable. This POC targets Android; physical-device/WebView behavior must be checked separately from a desktop-browser DOM test.

## Validation

`flutter test` covers URL restrictions, target-versus-viewport coordinates, Places IDs, category-based button defaults, WebView JSON encoding, native selection/review import, cancellation and stale completion, and short/landscape layouts. Existing editor/export checks also run.

The exact JS asset can be evaluated by Playwright for a live search → result → details check. Browser research artifacts stay outside the repository; no downloaded Google HTML, Google frontend keys, real review fixtures or private shared coordinates are committed.

Build the branch with `bash tool/build_android.sh`, or the pinned Actions debug workflow. The branch-specific package verifier expects the separate POC application ID. All builds and Flutter/native tests run sequentially because generated plugin registration is shared.
