# Mockareel Android preview

[Download v0.10.1 APK](https://github.com/jc-tanedo/mockareel/raw/refs/heads/apk-preview/mockareel-0.10.1.apk)

Install over your current preview; the signing certificate and application ID are unchanged.

## v0.10.1 — tablet typing fix and repository cleanup

- Fixed the FYP search field losing focus and closing the keyboard when a tablet/wide editor switches into keyboard layout. A stable inspector now retains the text field, input connection and edits.
- Hardened portable-backup imports with ZIP preflight, bounded extraction, malformed-schema handling and cleanup on failure.
- Split app startup, theme, editor screens, dialogs and models into clearer modules. Project data remains compatible.
- Shorter README and linked guides; private security-reporting guidance, ongoing redacted secret scanning and formatting checks.

Home-screen visuals are unchanged while more accurate reference examples are being gathered.

[Repository audit report](https://github.com/jc-tanedo/mockareel/blob/main/docs/security-review-2026-10-24.md) · [User guide](https://github.com/jc-tanedo/mockareel/blob/main/docs/user-guide.md)

Source: `cb5a0bbf0289efd5e676f2fc46d5c1101362e27c` on `main` and `work`.

Validation: 51 Flutter tests, five Kotlin motion tests, five release-metadata tests, clean analysis/formatting, workflow linting, Markdown link checks and a release APK build. Signature, ZIP integrity and 16 KB alignment checks passed. No credential-pattern matches were found in this APK. Native encoding still needs physical-device verification.

SHA-256: `71de3fc8b860c387e290ea04cc79e32972240e07074ba26489d6658113595cde`

Earlier versioned APKs and preview images remain on this branch.
