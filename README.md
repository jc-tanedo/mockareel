# Mockareel Android preview

[Download v0.6.0 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.6.0.apk)

Install over the previous preview using the same development signing key.

## v0.6.0

Choose **Place → Output theme → Light / Dark** below the preview. The setting applies to the reel's place sheet, typography, buttons, review card, gallery gaps and progress indicators. It affects preview, MP4, transparent PNG and snapshot PNG, and is saved per project and included in portable backups. The editor retains its existing appearance. Media images keep their original colors.

Existing projects default to Light until changed.

Source: `06b836d6d32f1bac436c096472a92450ea4c682c` on `work`.

Validation: static analysis clean, 28 Flutter tests, 4 native motion tests, dark template visual review, release build and APK integrity/signature checks. Native encoding still needs physical-device verification.

[Dark output preview](output-dark-0.6.0.png) · [Light output preview](output-light-0.6.0.png)

The images demonstrate Flutter rendering with crops from the supplied reference recordings; they are not recordings of native Android MP4 export. The gallery photos are illustrative.

SHA-256: `6bf529f190124ce03c30f97fd5185f68057f6701765bb22602a752812616d275`

Earlier versioned APKs and reference previews remain available on this branch.
