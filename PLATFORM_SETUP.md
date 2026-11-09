# LAND METRICS — Android, tablets, iPhone and iPad

This is a Flutter/Dart source project. Flutter supports Android phones, Android tablets, iPhone and iPad from the same Dart codebase. The ZIP contains app source, not precompiled installation packages.

## Generate native platform folders

Install Flutter (stable channel) and run these commands from the `land_metrics` directory:

```bash
flutter create --platforms=android,ios,web .
flutter pub get
flutter analyze
```

The generated `android/` folder builds Android phones and tablets. The generated `ios/` folder builds iPhone and iPad. `web/` can be used for a browser-based tablet/desktop experience.

## Run on Android phone or tablet

Enable USB debugging on the Android device or start an Android emulator, then:

```bash
flutter devices
flutter run
```

Build an installable Android APK:

```bash
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.

## Run/build for iPhone or iPad

**Requirement:** macOS with Xcode installed. Apple does not support compiling/signing iOS apps directly on Windows.

```bash
flutter doctor
flutter build ios --release
```

Open `ios/Runner.xcworkspace` in Xcode to configure signing/team and deploy to a physical iPhone/iPad. For App Store distribution, configure the bundle identifier, signing, icons, privacy details, and App Store Connect in Xcode.

## Tablet and responsive layout

Test the UI on multiple screen sizes using Android tablet/iPad simulators and physical devices. Review wide-screen spacing and orientation before release; this starter is not yet a fully validated production tablet layout.

## Ad photo uploads

The ad composer lets a user select an image from the device gallery. For cloud publishing, configure `SUPABASE_URL` and `SUPABASE_ANON_KEY`, create the `ad-images` Storage bucket, and apply secure Storage/database policies. Use only the anon/public client key in the app—never a Supabase service-role key. Validate upload permissions and ad moderation before public launch.

## Current scope

This is a starter conversion of the supplied JavaScript app. It does not yet represent a verified, complete port of every original screen or workflow, and no signed APK/IPA is included. Run tests and verify authentication, data access, payments, uploads, and tablet layouts before production release.
