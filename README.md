# LAND METRICS — Flutter / Dart

A Flutter/Dart starter conversion of the supplied LAND OGA JavaScript app, rebranded as **LAND METRICS**. Includes an Explore feed, property cards, bottom navigation, and an ad composer with gallery image selection and optional Supabase upload.

## Supported targets

One Dart codebase can target Android phones, Android tablets, iPhone, iPad, and web. This archive contains source code; generate the native platform folders and build installation packages using the guide in `PLATFORM_SETUP.md`.

## Requirements

- Flutter stable SDK and Dart 3.3+
- Android Studio / VS Code with Flutter extension for Android
- macOS and Xcode for building/signing iOS apps

## Quick start

From this folder, run:

```bash
flutter create --platforms=android,ios,web .
flutter pub get
flutter run
```

## Supabase configuration

Set the URL and anon key when running:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Create an `ad-images` Storage bucket and configure secure Storage policies. The app attempts to insert ad details into `advertisements` with fields `title`, `description`, `location`, `price`, `image_url`, and `status`. Ensure your table, column types, row-level security and bucket policies match before enabling public posting. Never embed a Supabase service-role key in a client app.

See `PLATFORM_SETUP.md` for Android APK and iOS/iPad build instructions. The supplied SQL schema is under `supabase/schema.sql`; review and apply migrations intentionally. This starter focuses on the main app experience and ad image flow; it is not a claim that every original screen, backend workflow, authentication or payment integration has been fully ported or tested. Run `flutter analyze` and test against a development Supabase project before production use.
