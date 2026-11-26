# Google Maps · optional API setup

[← README](../README.md)

**No API key is needed for browser place search, browser map-header capture, manual editing or export.** The default flow searches Google Maps in an attached WebView and imports editable fields. **Place → Header → Load Google map** opens a map-framing screen; save the visible map as a project image. Uploaded maps and photo headers remain available.

If a browser search times out on Android, the picker tries the same place name
in Android location search. You can also type a place and city and choose
**Use Android location search** from the search menu. Select the matching
address to import its pin. Availability depends on the device’s geocoder.

The selected place card shows its latitude and longitude before import. If
the Maps link and Android lookup do not identify a pin, the app can check the
English Wikipedia entry for a landmark with a website. It sends the place name
and checks the returned title, locality, website link and primary coordinates
against the listing. Saved 3D locations use the same lookup when reopened.

For API access, open the editor's **More project options → Advanced · Google Maps**, enter your own Google Cloud key and save. Choose **Use API lookup** in the search menu for API search. Enable **Use API map headers** in advanced settings to make **Load Google map** use the automatic static-image service instead of browser framing. Saving a key alone does not change header mode.

## APIs to enable

| Google Cloud API | Used for | Required when |
| --- | --- | --- |
| **Places API (New)** | Text Search, including names, addresses, ratings, contact details, categories and coordinates | Using **Use API lookup** |
| **Maps Static API** | A map image with a location marker and selected zoom | **Use API map headers** is enabled |

Enable billing in the same Google Cloud project for API requests. Enable only the APIs you use. **Maps SDK for Android, Maps JavaScript API and Geocoding API are not required by Mockareel.** Browser mode uses the Google Maps website and does not use these developer APIs. Fields/reviews and page rendering can vary; manual editing and image upload are always available.

## Key restrictions and storage

Restrict the key to the required APIs and set quotas/budget alerts in Google Cloud. The app currently calls the REST/static HTTP endpoints directly, rather than using the Android Maps SDK. Android package/SHA restrictions alone may not authorize those requests; select restrictions supported by the relevant web API. A server-IP restriction cannot match arbitrary phones. A backend proxy is preferable if distributing a shared developer key.

On-device keys are stored in app-private preferences, not encrypted credential storage, and are excluded from `.mockareel` backups. Clear the key field and save to remove it. A build-time key can be supplied using `--dart-define=MAPS_API_KEY=...`; build-time keys are extractable from an APK. A saved on-device setting takes precedence, including an explicitly cleared key. Never embed a server credential.

`tool/build_android.sh` can include a real `MAPS_API_KEY` environment value; cloud secret-proxy placeholders are skipped. The script never prints the key. Official release APKs are built without an embedded key; add a personal key in advanced settings only if you want API access.
