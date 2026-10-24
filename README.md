# Mockareel Android preview

[Download v0.5.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.5.0.apk)

Install over the previous preview using the same development signing key.

## v0.5.0

- Map headers from Google Maps Static API, using the retrieved place coordinates and adjustable zoom, or upload a map image. The Photo header option remains available.
- Opening scroll reveal: the place sheet slides up over the map, followed by horizontal card slides, page counter, dots and timed progress line. Adjustable 0–2 second intro; zero disables it.
- Optional featured review: editable reviewer name, star rating and text. Empty or disabled reviews remain hidden.
- Map images, animation settings and reviews persist in saved projects and portable backups.

In Place, expand **Header image** to choose Map and load/upload an image. Google map loading needs **Maps Static API** enabled for your device's key, with billing and compatible restrictions. Expand **Featured review (optional)** to add a review. In Timeline, adjust **Opening scroll reveal**. Older projects keep their existing photo header and disabled intro until changed.

Source: `08e06694a24142f07c80033bbb46f9ad3ca81a47` on `work`.

Validation: static analysis clean, 26 Flutter tests, 4 native motion tests, visual frame review, release build and APK integrity/signature checks. Native encoding and live map loading still need physical-device verification.

[Animation preview](maps-preview-0.5.0.gif) · [Settled template](maps-template-0.5.0.png) · [Opening frame](maps-opening-0.5.0.png)

The animation demonstrates Flutter rendering with crops from the supplied reference recordings; it is not a recording of native Android MP4 export. The gallery photos are illustrative.

SHA-256: `ef6f8bcc80614643b6ab55eb0515605d9d49ad49afbdb5f644558c8c1bc959ed`

Earlier versioned APKs remain available on this branch.
