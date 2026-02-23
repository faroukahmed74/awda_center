# Release builds and how to run

## Build commands (release)

```bash
cd /Users/ahmedfarouk/StudioProjects/awda_center

# Android APK (installable on devices)
flutter build apk --release

# Web (output: build/web)
flutter build web --release

# iOS (requires Xcode + Development Team for a deployable app)
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode, select Runner target → Signing & Capabilities → set Team.

# macOS (requires enough free disk space)
flutter build macos --release
```

## Where the built outputs are

| Platform | Output path |
|----------|-------------|
| **Android** | `build/app/outputs/flutter-apk/app-release.apk` |
| **Web** | `build/web/` (static files; serve with any HTTP server) |
| **iOS** | `build/ios/iphoneos/Runner.app` (after successful signed build) |
| **macOS** | `build/macos/Build/Products/Release/awda_center.app` |

## Run the app (release mode)

```bash
# Web (Chrome)
flutter run -d chrome --release

# macOS desktop
flutter run -d macos --release

# Android (device or emulator)
flutter run -d android --release

# iOS (simulator; for device you need signing in Xcode)
flutter run -d ios --release
```

## Serve the built web app

To serve the **already built** web output (e.g. for deployment or local testing):

```bash
# Using Python 3
cd build/web && python3 -m http.server 8080
# Then open http://localhost:8080

# Or using Flutter
flutter pub global activate webdev
flutter pub global run webdev serve build/web --port=8080
```

## Notes

- **iOS release**: You must set a **Development Team** in Xcode (Runner target → Signing & Capabilities) and have a valid Apple Developer account to build a deployable IPA or run on a real device.
- **macOS release**: If the build fails with "No space left on device", free disk space on Macintosh HD and run `flutter build macos --release` again.
- **Android**: Install the APK on a device with `adb install build/app/outputs/flutter-apk/app-release.apk` (with device connected), or run `flutter run -d android --release` to build and run in one step.
