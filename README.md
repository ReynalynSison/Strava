# Strivo

An iOS-style running tracker inspired by Strava, built with Flutter.

Strivo is local-first: runs and app preferences are stored on-device with Hive, with support for route recording, feed/history views, post-run photo overlays, and shareable run cards.

## Features

- Sign up / sign in with optional biometric unlock
- GPS run tracking with route capture, pace, duration, and distance
- Post-run flow with optional photo and feed caption
- Activity feed, history list, and profile analytics
- Shareable run preview cards (map mode + styled photo mode)
- Local notifications for active run controls (pause/resume)
- Dark/light mode and unit preferences (km/mi)

## Tech Stack

- **Framework:** Flutter (Cupertino-first UI)
- **State:** Riverpod + stateful UI where needed
- **Storage:** Hive / hive_flutter
- **Location:** geolocator
- **Map rendering:** flutter_map + latlong2
- **Notifications:** flutter_local_notifications
- **Media / sharing:** image_picker, camera, share_plus
- **Auth:** local_auth

## Project Structure

```text
lib/
  main.dart                 # App bootstrap, Hive init, login entry
  homepage.dart             # Tab scaffold (Feed, History, Record, You, Settings)
  signup.dart               # Account creation
  settings.dart             # Preferences, biometrics, data tools
  models/
    activity_model.dart
  providers/
    ...                     # App/activity/tracking providers
  screens/
    home_screen.dart
    history_screen.dart
    record_screen.dart
    activity_summary_screen.dart
    run_photo_screen.dart
    you_screen.dart
    ...
  services/
    tracking_service.dart
    location_service.dart
    storage_service.dart
    share_service.dart
    run_notification_service.dart
    ...
  widgets/
    activity_card_widget.dart
    route_map_widget.dart
    shareable_card_widget.dart
    ...
```

## Local Data Model

### Hive box: `database`
Stores account + app settings:
- `username`
- `password`
- `darkMode`
- `useMetric`
- `biometrics`
- profile/avatar-related values

### Hive box: `activities`
Stores serialized `ActivityModel` entries:
- `id`
- `distance` (meters)
- `durationSeconds`
- `pace` (min/km)
- `date`
- `routeCoordinates` (`List<Map<String,double>>` with `lat`/`lng`)
- `caption` (optional)
- `postedToFeed` (bool)
- `photoPath` (optional)

## Core Flow

1. Request location permission
2. Start tracking stream
3. Collect/validate points and update route metrics
4. Stop run and create `ActivityModel`
5. Optional post-run photo + feed metadata
6. Persist to Hive
7. Show run summary and optional sharing

## Getting Started

### Prerequisites

- Flutter SDK (stable)
- Android Studio or Xcode (for device/simulator runs)

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

### Run tests

```bash
flutter test
```

## Platform Notes

- Location and notification permissions must be configured in platform manifests/plists.
- For Android location tracking (SDK 34+), ensure required foreground location permissions are present in `AndroidManifest.xml`.

## Development Notes

- Keep Hive schema/model behavior stable unless explicitly migrating.
- Avoid changing dependency versions casually; use `flutter pub get` if packages appear unresolved.
- Do not run `flutter clean` unless explicitly needed.

---

If you are onboarding to this repo, start with:
- `CONTEXT.md`
- `lib/main.dart`
- `lib/screens/record_screen.dart`
- `lib/services/tracking_service.dart`
- `lib/providers/tracking_provider.dart`

