import '../models/activity_model.dart';
import 'storage_service.dart';

/// Injects a realistic demo run into the activities box so you can
/// test the Feed, History, Summary, and animated route without running.
///
/// The route is a ~2 km loop around a city block in Lisbon, Portugal.
/// Call [seedDemoRun] once; it saves and returns the activity.
class DemoService {
  final StorageService _storage = StorageService();

  // ── ~2 km Lisbon loop — 40 GPS points ──────────────────────────────────────
  static const List<Map<String, double>> _demoRoute = [
    {'lat': 38.7169, 'lng': -9.1399},
    {'lat': 38.7173, 'lng': -9.1392},
    {'lat': 38.7178, 'lng': -9.1383},
    {'lat': 38.7183, 'lng': -9.1374},
    {'lat': 38.7189, 'lng': -9.1365},
    {'lat': 38.7195, 'lng': -9.1357},
    {'lat': 38.7201, 'lng': -9.1349},
    {'lat': 38.7207, 'lng': -9.1342},
    {'lat': 38.7213, 'lng': -9.1335},
    {'lat': 38.7218, 'lng': -9.1328},
    {'lat': 38.7222, 'lng': -9.1320},
    {'lat': 38.7225, 'lng': -9.1312},
    {'lat': 38.7226, 'lng': -9.1303},
    {'lat': 38.7225, 'lng': -9.1294},
    {'lat': 38.7222, 'lng': -9.1286},
    {'lat': 38.7218, 'lng': -9.1279},
    {'lat': 38.7213, 'lng': -9.1273},
    {'lat': 38.7207, 'lng': -9.1268},
    {'lat': 38.7200, 'lng': -9.1264},
    {'lat': 38.7193, 'lng': -9.1262},
    {'lat': 38.7185, 'lng': -9.1261},
    {'lat': 38.7177, 'lng': -9.1263},
    {'lat': 38.7170, 'lng': -9.1267},
    {'lat': 38.7163, 'lng': -9.1272},
    {'lat': 38.7157, 'lng': -9.1279},
    {'lat': 38.7152, 'lng': -9.1287},
    {'lat': 38.7149, 'lng': -9.1296},
    {'lat': 38.7148, 'lng': -9.1305},
    {'lat': 38.7149, 'lng': -9.1314},
    {'lat': 38.7152, 'lng': -9.1323},
    {'lat': 38.7156, 'lng': -9.1331},
    {'lat': 38.7161, 'lng': -9.1339},
    {'lat': 38.7165, 'lng': -9.1347},
    {'lat': 38.7167, 'lng': -9.1356},
    {'lat': 38.7168, 'lng': -9.1365},
    {'lat': 38.7168, 'lng': -9.1374},
    {'lat': 38.7168, 'lng': -9.1383},
    {'lat': 38.7168, 'lng': -9.1391},
    {'lat': 38.7169, 'lng': -9.1397},
    {'lat': 38.7169, 'lng': -9.1399},
  ];

  /// Seeds a demo run and returns the saved [ActivityModel].
  Future<ActivityModel> seedDemoRun() async {
    final activity = ActivityModel(
      distance: 2134.0,          // ~2.1 km
      durationSeconds: 780,      // 13:00 — realistic 6:08/km pace
      pace: 6.08,
      date: DateTime.now().subtract(const Duration(hours: 2)),
      routeCoordinates: _demoRoute,
      caption: 'Demo run 🏃 Lisbon loop',
      postedToFeed: true,
    );
    await _storage.saveActivity(activity);
    return activity;
  }

  /// Seeds a zero-distance (stationary) demo to test the single-point dot.
  Future<ActivityModel> seedStationaryDemo() async {
    final activity = ActivityModel(
      distance: 0,
      durationSeconds: 30,
      pace: 0,
      date: DateTime.now().subtract(const Duration(minutes: 10)),
      routeCoordinates: const [
        {'lat': 38.7169, 'lng': -9.1399},
      ],
      caption: 'Stationary test',
      postedToFeed: true,
    );
    await _storage.saveActivity(activity);
    return activity;
  }
}

