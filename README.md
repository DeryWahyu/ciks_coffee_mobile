# ciks_coffee_mobile

## Cart and order confirmation

The cart uses a single checkout panel above the safe navigation area. It shows
the QRIS method, total, and a full-width payment button, with a scrollable layout
for short screens and larger text. Cancelling the QRIS sheet retains the cart;
submission still requires a selected payment proof for cashier verification.

`coffee_overlays.dart` supplies shared dialog/sheet surfaces and action buttons
for pickup, payment, success, variants, order details, logout, and profile
information. The **Sudah Ambil** confirmation explicitly explains when an order
enters transaction history. Orders remain active until the pickup API succeeds.
Deploy the corresponding web/API changes for the shared transaction-history rule.

Run `flutter test` for responsive checkout, cancellation/proof requirements,
explicit pickup confirmation, keyboard spacing, and existing application checks.

Production APKs are published by GitHub Actions to the isolated
`cikscoffee-dery` Docker stack on `45.66.153.149`, SSH port `20193`.
The public API remains `https://cikscoffee.biz.id/api` and the download URL
remains `https://cikscoffee.biz.id/downloads/cikscoffee-latest.apk`.
The existing signing certificate is retained for installation updates.

## Smaller Android downloads

Run `flutter pub get`, then
`python tool/build_android_release.py --build-number=1021` (use a build number
newer than the installed release). Packages are written to `build/android-release`:

| APK | Device |
| --- | --- |
| `ciks-coffee-mobile-arm64-v8a.apk` | ARM 64-bit Android |
| `ciks-coffee-mobile-armeabi-v7a.apk` | ARM 32-bit Android |
| `ciks-coffee-mobile-x86_64.apk` | x86 64-bit Android |
| `app-release.apk` | Universal fallback for all supported architectures |

Install one matching APK. With ADB connected, `adb shell getprop ro.product.cpu.abilist`
lists supported architectures; use ARM64 when `arm64-v8a` appears. Each package
has the same application ID, signing key, features, and versionCode, so choosing
a smaller APK preserves installed account data. All packages include the floating
navbar and existing checkout/pickup changes.
For local updates, set `CIKS_ANDROID_KEYSTORE` to the existing installation's
keystore. CI restores this key and checks its pinned signing certificate.

The build keeps Dart debug symbols in `build/android-symbols/<architecture>`
instead of bundling them into the APK. Archive those alongside each release for
`flutter symbolize`; CI retains them as a separate artifact for 90 days.
The builder uses separate `--target-platform` builds so all APKs retain the same
versionCode (Flutter's `--split-per-abi` adds per-ABI offsets).
It also sets Gradle ABI filters for native plugin dependencies and validates that
each advertised architecture contains both application code and a Flutter engine.
Run `python -m unittest discover -s tool -p 'test_*.py'` for these packaging checks.

CI publishes all device APKs and `SHA256SUMS.txt` on GitHub Releases; its build
artifact also includes a size/checksum manifest.
After publishing the first optimized release, the ARM64 file is available at
`https://github.com/DeryWahyu/ciks_coffee_mobile/releases/latest/download/ciks-coffee-mobile-arm64-v8a.apk`.
The existing server download remains the universal fallback. The device APKs
reduce download and installed native-code overhead by omitting unused processors;
they do not compress native libraries and extract additional copies at install.
See the [Flutter size guide](https://docs.flutter.dev/perf/app-size).

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
