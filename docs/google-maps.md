# Google Maps setup

[← README](../README.md)

The app uses **Places API (New)** Text Search. Enable it and billing in Google Cloud. Set a key with `--dart-define=MAPS_API_KEY=...` or enter it in the app's Settings. An on-device key takes precedence. Keys are not included in project backups or Git source. Google map headers additionally require **Maps Static API**, billing, and key restrictions that permit the request. They use the retrieved latitude/longitude, a location marker and selected zoom. Uploaded map images work without Maps Static API. Keep map attribution visible in images you upload.

`tool/build_android.sh` includes a real `MAPS_API_KEY` environment value when available; cloud secret-proxy placeholders cannot authenticate from a phone and are skipped. The script never prints the key. Manual editing and rendering need no Maps key.


API keys entered on a device are stored in app-private preferences, not encrypted credential storage. Build-time keys are extractable from APKs. Use a restricted client key with only the required APIs enabled and appropriate quotas; never embed a server credential. Personal keys are not included in `.mockareel` backups.
