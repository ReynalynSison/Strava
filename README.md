# Strivo

Strivo is a local-first running tracker built with Flutter and a clean Cupertino style.

It helps you record runs, review your route, post to your feed, and share your activity cards - all stored on-device with Hive.

## What You Can Do

- Create an account and sign in (with optional biometrics)
- Track runs with GPS (distance, pace, duration, live route)
- Add a post-run photo and caption
- View activity feed, history, and profile stats
- Share run cards (Map mode + Photo Styled mode)
- Use dark/light mode and switch between km/mi

## Tech Stack

- **Flutter** (Cupertino UI)
- **Riverpod** (state management)
- **Hive / hive_flutter** (local storage)
- **geolocator** (GPS)
- **flutter_map + latlong2** (map rendering)
- **flutter_local_notifications** (run notifications)
- **image_picker / camera / share_plus** (media + sharing)
- **local_auth** (biometric auth)

## Project File Tree

```text
Strava/
|- README.md
|- pubspec.yaml
|- android/
|- ios/
|- assets/
|- test/
`- lib/
   |- main.dart
   |- homepage.dart
   |- signup.dart
   |- settings.dart
   |
   |- models/
   |  `- activity_model.dart
   |
   |- providers/
   |  |- app_providers.dart
   |  |- app_settings_provider.dart
   |  |- tracking_provider.dart
   |  `- ...
   |
   |- screens/
   |  |- home_screen.dart
   |  |- history_screen.dart
   |  |- record_screen.dart
   |  |- activity_summary_screen.dart
   |  |- run_photo_screen.dart
   |  |- animated_route_screen.dart
   |  |- camera_overlay_screen.dart
   |  |- you_screen.dart
   |  `- ...
   |
   |- services/
   |  |- tracking_service.dart
   |  |- location_service.dart
   |  |- storage_service.dart
   |  |- share_service.dart
   |  |- run_notification_service.dart
   |  `- ...
   |
   |- widgets/
   |  |- activity_card_widget.dart
   |  |- activity_stats_widget.dart
   |  |- route_map_widget.dart
   |  |- route_outline_painter.dart
   |  |- shareable_card_widget.dart
   |  `- ...
   |
   `- utils/
      |- constants.dart
      `- formatters.dart
```

## Quick Start

### 1) Install dependencies

```bash
flutter pub get
```

### 2) Run the app

```bash
flutter run
```

### 3) Run tests

```bash
flutter test
```

## Data Storage (Hive)

### `database` box

Stores account/settings values such as:

- `username`
- `password`
- `darkMode`
- `useMetric`
- `biometrics`

### `activities` box

Stores serialized `ActivityModel` values:

- `id`
- `distance` (meters)
- `durationSeconds`
- `pace` (min/km)
- `date`
- `routeCoordinates` (`List<Map<String,double>>` with `lat`/`lng`)
- `caption` (optional)
- `postedToFeed` (bool)
- `photoPath` (optional)

## Main User Flow

1. Request location permission
2. Start tracking (`TrackingService`)
3. Collect/filter GPS points and update metrics
4. Stop run and build `ActivityModel`
5. Optional photo + feed post details
6. Save to Hive
7. Open summary and share

## Notes for Contributors
- Do not remove or modify dependencies in `pubspec.yaml` unless requested.
- If packages are unresolved, run `flutter pub get`.
- Do not run `flutter clean` unless explicitly requested.

## Good First Files to Read

- `lib/main.dart`
- `lib/screens/record_screen.dart`
- `lib/services/tracking_service.dart`
- `lib/providers/tracking_provider.dart`

