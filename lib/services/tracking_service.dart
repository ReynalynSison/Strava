import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/activity_model.dart';
import '../utils/gps_filtering.dart';
import 'location_service.dart';

/// Manages the state of a single run tracking session.
/// Owns live run lifecycle details such as GPS subscription, timer refreshes,
/// distance/pace computation, and current position/error/loading state.
class TrackingService {
  TrackingService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  static const double _minPointDistanceMeters = 5.0;
  static const bool _enableMovingAverageWindow = false;

  // ─── State ────────────────────────────────────────────────────────────────

  final LocationService _locationService;
  final List<Map<String, double>> routeCoordinates = [];
  final Stopwatch _stopwatch = Stopwatch();
  StreamSubscription<Position>? _positionStream;
  Timer? _ticker;
  void Function()? _onUpdate;

  Position? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPaused = false;
  bool _isTracking = false;

  // ─── Getters ──────────────────────────────────────────────────────────────

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;

  /// Total distance covered so far, in kilometers.
  double get currentDistanceKm {
    final meters = _locationService.calculateDistance(routeCoordinates);
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

  void bind(void Function() onUpdate) {
    _onUpdate = onUpdate;
  }

  void _notify() => _onUpdate?.call();

  Future<void> initializeLocation() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();

    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) {
      _isLoading = false;
      _errorMessage = 'Location permission denied';
      _notify();
      return;
    }

    try {
      _currentPosition = await _locationService.getCurrentLocation();
      _isLoading = false;
      _errorMessage = null;
      _notify();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to get location: $e';
      _notify();
    }
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  // ─── Controls ─────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
  }

  void startTracking() {
    _positionStream?.cancel();
    _ticker?.cancel();
    routeCoordinates.clear();
    _stopwatch.reset();
    _stopwatch.start();
    _isTracking = true;
    _isPaused = false;

    _positionStream = _locationService.getPositionStream().listen((position) {
      _currentPosition = position;
      addCoordinate(position.latitude, position.longitude);
      _notify();
    });

    _startTicker();
    _notify();
  }

  void pauseTracking() {
    _stopwatch.stop();
    _isPaused = true;
    _positionStream?.pause();
    _ticker?.cancel();
    _notify();
  }

  void resumeTracking() {
    _stopwatch.start();
    _isPaused = false;
    _positionStream?.resume();
    _startTicker();
    _notify();
  }

  /// Clears all live tracking session state so the next run starts clean.
  void resetSession() {
    _positionStream?.cancel();
    _positionStream = null;
    _ticker?.cancel();
    _ticker = null;
    routeCoordinates.clear();
    _stopwatch
      ..stop()
      ..reset();
    _isTracking = false;
    _isPaused = false;
    _errorMessage = null;
  }

  /// Stops tracking and returns the completed ActivityModel.
  ActivityModel stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.stop();
    _isTracking = false;
    _isPaused = false;

    final distanceMeters =
        _locationService.calculateDistance(routeCoordinates);
    final durationSecs = _stopwatch.elapsed.inSeconds;
    // Guard: distance < 100 m means essentially stationary — save 0.0 so
    // the UI shows --'--" instead of an absurd pace like 76'47"/km.
    final pace = distanceMeters >= 100 ? currentPaceMinPerKm : 0.0;

    final outputCoordinates = applyMovingAverageWindow(
      routeCoordinates,
      enabled: _enableMovingAverageWindow,
    );

    return ActivityModel(
      distance: distanceMeters,
      durationSeconds: durationSecs,
      pace: pace,
      date: DateTime.now(),
      routeCoordinates: List<Map<String, double>>.from(outputCoordinates),
    );
  }

  /// Adds a new GPS coordinate point to the route.
  /// Only adds if not paused and tracking is active.
  void addCoordinate(double lat, double lng) {
    if (!_isTracking || _isPaused) return;

    if (routeCoordinates.isNotEmpty) {
      final last = routeCoordinates.last;
      final distance = Geolocator.distanceBetween(
        last['lat']!,
        last['lng']!,
        lat,
        lng,
      );
      if (distance < _minPointDistanceMeters) return;
    }

    routeCoordinates.add({'lat': lat, 'lng': lng});
  }

  void tick() => _notify();

  void dispose() {
    _positionStream?.cancel();
    _ticker?.cancel();
  }
}
