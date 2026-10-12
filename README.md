# ciks_coffee_mobile

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
