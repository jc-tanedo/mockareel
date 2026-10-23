# Mockareel

Mockareel is a Flutter editor for vertical place-story reels. The first template recreates the Google Maps Place story shown in the reference clip.

## Current editor

- Search for a place by opening Google Maps with the current place name, then edit the place title, category, rating, and location in the app.
- Add multiple photos and videos from the device library.
- Edit scene timing and review the five-card left-scroll story.
- Save an editable project draft on the device or share its JSON project description.

Place lookup uses Google Maps search and does not require an API key. Project files contain media paths rather than copies of the selected media. Rendering a finished MP4 is a follow-up feature; this first version saves and shares the editable project.

## Run and build

Use Flutter stable with the Android SDK installed. From this directory:

```sh
flutter pub get
flutter run
flutter build apk --release
```

The release APK is written to `build/app/outputs/flutter-apk/app-release.apk`.
