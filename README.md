# ciks_coffee_mobile

Production APKs are published by GitHub Actions to the isolated
`cikscoffee-dery` Docker stack on `45.66.153.149`, SSH port `20193`.
The public API remains `https://cikscoffee.biz.id/api` and the download URL
remains `https://cikscoffee.biz.id/downloads/cikscoffee-latest.apk`.
The existing signing certificate is retained for installation updates.

## Mobile branding

The aroma mark in `assets/branding/cikscoffee-mark.png` is the approved,
enlarged web mark. `BrandMark` shares it across splash, login, registration,
home, profile/about, and order status. Coffee category and product placeholder
icons keep their functional meaning.

The Flutter splash uses warm cream, espresso, locally drawn cup-ring outlines,
and bundled Inter/Playfair Display fonts. It works without downloading imagery
or fonts, adapts to small screens and larger text, and respects reduced motion.
The existing authentication and token validation still control when it closes.

Native Android launch screens (including Android 12+) and iOS use the same mark
and cream background. Android adaptive/themed icons, notification silhouettes,
iOS, web, Windows, and macOS icons are exported from that single source.
Android launch resources follow the [Flutter splash guidance](https://docs.flutter.dev/platform-integration/android/splash-screen).

Regenerate platform assets without changing the approved artwork:

```powershell
dart run tool/generate_brand_assets.dart
dart run flutter_launcher_icons
```

Font files come from [Google Fonts](https://github.com/google/fonts), with
their SIL Open Font License notices in `assets/fonts/`.
Already-installed applications need the new APK to receive the branding.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Production API

The application connects to `https://cikscoffee.biz.id/api` in every build.
The local server selector has been removed. Existing installations discard
saved development-server addresses and their authentication tokens on startup.

Build the Android APK from this directory:

```powershell
flutter build apk --release
```

Android builds require HTTPS. Customer accounts use the mobile application;
owner and employee accounts use the web interface.

## Automatic Android builds

Push to `main` to run Flutter analysis/tests, build an APK on Flutter 3.41.6,
verify the compiled production API URL, and publish to GitHub Releases and
`https://cikscoffee.biz.id/downloads/cikscoffee-latest.apk`. Pull requests run
checks without publishing. The Actions tab also supports a manual run of main.

Actions secrets: `VPS_HOST`, `VPS_PORT`, `VPS_USER`, `VPS_SSH_KEY`,
`VPS_KNOWN_HOSTS`, and `ANDROID_DEBUG_KEYSTORE_B64`. The VPS SSH key is limited
to APK publication and cannot deploy backend code. GitHub Releases use the
workflow's built-in `GITHUB_TOKEN` rather than a personal access token.

The signing secret contains the existing manual-install debug keystore, so
new builds can update the installed production APK without changing its
signing identity. CI sets versionCode to `1000 + GITHUB_RUN_NUMBER`. A dedicated
release signing configuration is still needed for Play Store distribution.
Users download and install the new APK; server publication does not update
already-installed apps automatically.
