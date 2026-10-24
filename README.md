# Mockareel Android preview

[Download v0.10.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.10.0.apk)

Install over the previous preview. The development signing certificate is unchanged, so saved projects and settings are preserved.

## v0.10.0 — home screen OS presets and screenshot controls

In the FYP editor, open **Sequence → Home screen & status bar**.

- Select iPhone (iOS), standard Android, Google Pixel or Samsung One UI. Each preset has distinct clock/widget styling, icon shapes, dock and launcher navigation. Launch/close animation targets match the selected layout.
- **Show mock app icons** hides/shows the generated grid, dock, page indicators and launcher navigation. Custom labels and icon choices are retained when hidden.
- Clock/date, widget and status bar have independent visibility switches.
- After supplying a photo/video, **Use media without overlays** hides all generated home chrome and removes its dimming. Use this for screenshots or recordings that already contain their own icons and widgets.
- The OS and all visibility choices persist through autosave, reopening and portable backups. Older projects keep the iPhone preset and visible icons.

[ iPhone ](home-iphone-0.10.0.png) · [ Android ](home-android-0.10.0.png) · [ Pixel ](home-pixel-0.10.0.png) · [ Samsung One UI ](home-oneUi-0.10.0.png)

Screenshots are Flutter renders, not physical-device captures. Existing Maps and FYP features remain available; older versioned APKs and previews are preserved on this branch.

Source: `13d2f22f977b74281bda57f915aa7b28e3e635ec` on `work`.

Validation: 43 Flutter tests pass, static analysis is clean, all four presets were visually reviewed, and the release APK passed signature, archive and 16 KB alignment checks. Coverage includes saved OS/visibility settings, portable backups, editor controls, all preset layouts, icon/dock hiding, unmodified screenshot pixels, animated export UI capture and Maps regressions. Native encoding still needs physical-device verification; native renderer code is unchanged in this release.

SHA-256: `8ac23b2c1b025d47c5080b72314bcf70cded9757ca945380ef3ffe8bd5d760cd`
