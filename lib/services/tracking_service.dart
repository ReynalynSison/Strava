import '../models/activity_model.dart';
import 'location_service.dart';

/// Manages the state of a single run tracking session.
/// Used exclusively by RecordScreen — one instance per screen lifecycle.
class TrackingService {
  // ─── State ────────────────────────────────────────────────────────────────

  final List<Map<String, double>> routeCoordinates = [];
  final Stopwatch _stopwatch = Stopwatch();
  bool _isPaused = false;
  bool _isTracking = false;

  // ─── Getters ──────────────────────────────────────────────────────────────

  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;

  /// Total distance covered so far, in kilometers.
  double get currentDistanceKm {
    final meters = LocationService().calculateDistance(routeCoordinates);
    return meters / 1000;
  }

  /// Elapsed time formatted as mm:ss.
  String get formattedDuration {
    final elapsed = _stopwatch.elapsed;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Raw elapsed seconds — used for saving the activity.
  int get elapsedSeconds => _stopwatch.elapsed.inSeconds;

  /// Current pace in min/km. Returns 0.0 if not enough data.
  double get currentPaceMinPerKm {
    final km = currentDistanceKm;
    if (km < 0.01) return 0.0;
    final minutes = _stopwatch.elapsed.inSeconds / 60;
    return minutes / km;
  }

  /// Pace formatted as m'ss"/km. Returns "--'--"" if no data.
  String get formattedPace {
    final pace = currentPaceMinPerKm;
    if (pace <= 0.0) return "--'--\"";
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round().toString().padLeft(2, '0');
    return "$minutes'$seconds\"";
  }

  // ─── Controls ─────────────────────────────────────────────────────────────

  void startTracking() {
    routeCoordinates.clear();
    _stopwatch.reset();
    _stopwatch.start();
    _isTracking = true;
    _isPaused = false;
  }

  void pauseTracking() {
    _stopwatch.stop();
    _isPaused = true;
  }

  void resumeTracking() {
    _stopwatch.start();
    _isPaused = false;
  }

  /// Stops tracking and returns the completed ActivityModel.
  ActivityModel stopTracking() {
    _stopwatch.stop();
    _isTracking = false;
    _isPaused = false;

    final distanceMeters =
        LocationService().calculateDistance(routeCoordinates);
    final durationSecs = _stopwatch.elapsed.inSeconds;
    // Guard: distance < 100 m means essentially stationary — save 0.0 so
    // the UI shows --'--" instead of an absurd pace like 76'47"/km.
    final pace = distanceMeters >= 100 ? currentPaceMinPerKm : 0.0;

    return ActivityModel(
      distance: distanceMeters,
      durationSeconds: durationSecs,
      pace: pace,
      date: DateTime.now(),
      routeCoordinates: List<Map<String, double>>.from(routeCoordinates),
    );
  }

  /// Adds a new GPS coordinate point to the route.
  /// Only adds if not paused and tracking is active.
  void addCoordinate(double lat, double lng) {
    if (!_isTracking || _isPaused) return;
    routeCoordinates.add({'lat': lat, 'lng': lng});
  }
}
