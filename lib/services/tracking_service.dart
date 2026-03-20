import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:geolocator/geolocator.dart';

import '../models/activity_model.dart';
import 'location_service.dart';

/// Manages the state of a single run tracking session.
/// Owns live run lifecycle details such as GPS subscription, timer refreshes,
/// distance/pace computation, and current position/error/loading state.
class TrackingService {
  TrackingService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  // Balanced defaults: preserve road shape while still rejecting noisy jumps.
  static const double _maxAccuracyMeters = 30.0;
  static const double _minPointDistanceMeters = 2.0;
  static const double _maxSpeedMps = 12.0; // ~43 km/h, reasonable for running
  static const double _stationarySpeedMps = 1.0;
  // Do NOT use speedMps < 0.5 cutoff — it causes frozen markers (Bug 3)
  
  // ─── State ────────────────────────────────────────────────────────────────

  final LocationService _locationService;
  final List<Map<String, double>> routeCoordinates = [];
  final Stopwatch _stopwatch = Stopwatch();
  StreamSubscription<Position>? _positionStream;
  Timer? _ticker;
  Timer? _streamWatchdog; // ✅ Bug 3 Part B: detects silent stream death
  void Function()? _onUpdate;

  Position? _currentPosition;
  Position? _lastAcceptedRoutePosition; // Separate from currentPosition
  DateTime? _lastUpdateTime; // Track for stream watchdog
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
  // ✅ FIX 3: Added validation - only calculate distance if 2+ points (real movement)
  double get currentDistanceKm {
    if (routeCoordinates.length < 2) return 0.0;
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

  /// Updates only the live marker position outside an active run.
  void updatePreviewPosition(Position position) {
    _currentPosition = position;
    _isLoading = false;
    _errorMessage = null;
    _notify();
  }

  // ─── Controls ─────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
  }

  /// ✅ Bug 3 Part B: Stream watchdog detects silent stream death and restarts.
  void _startStreamWatchdog() {
    _streamWatchdog?.cancel();
    _streamWatchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isTracking || _isPaused) return;
      
      final lastUpdate = _lastUpdateTime;
      if (lastUpdate == null) return;
      
      final elapsed = DateTime.now().difference(lastUpdate);
      if (elapsed > const Duration(seconds: 5)) {
        debugPrint('[TrackingService] Stream watchdog: no update for ${elapsed.inSeconds}s, restarting...');
        _restartStream();
      }
    });
  }

  void _stopStreamWatchdog() {
    _streamWatchdog?.cancel();
    _streamWatchdog = null;
  }

  void _startPositionStream() {
    _positionStream?.cancel();
    _positionStream = _locationService.getPositionStream().listen(
      (position) {
        // ✅ Bug 3 Part A: Always update the marker position, never filter it
        _currentPosition = position;
        _lastUpdateTime = DateTime.now();
        
        // Only route filtering happens here
        addCoordinate(position);
        _notify();
      },
      onError: (e) {
        debugPrint('[TrackingService] Position stream error: $e');
        _restartStream();
      },
      onDone: () {
        debugPrint('[TrackingService] Position stream done, restarting...');
        _restartStream();
      },
      cancelOnError: false,
    );
  }

  void _restartStream() {
    if (!_isTracking || _isPaused) return;
    _startPositionStream();
  }

  // ✅ FIX 4: Removed initial position capture - prevents phantom distance at start
  void startTracking() {
    _positionStream?.cancel();
    _ticker?.cancel();
    _stopStreamWatchdog();
    routeCoordinates.clear();
    _lastAcceptedRoutePosition = null;
    _lastUpdateTime = null;
    _stopwatch.reset();
    _stopwatch.start();
    _isTracking = true;
    _isPaused = false;

    // Start GPS stream and watchdog
    _startPositionStream();
    _startStreamWatchdog();
    _startTicker();
    _notify();
  }

  void pauseTracking() {
    _stopwatch.stop();
    _isPaused = true;
    _positionStream?.pause();
    _ticker?.cancel();
    _stopStreamWatchdog();
    _notify();
  }

  void resumeTracking() {
    _stopwatch.start();
    _isPaused = false;
    _positionStream?.resume();
    _lastUpdateTime = DateTime.now();
    _startTicker();
    _startStreamWatchdog();
    _notify();
  }

  /// Clears all live tracking session state so the next run starts clean.
  void resetSession() {
    _positionStream?.cancel();
    _positionStream = null;
    _ticker?.cancel();
    _ticker = null;
    _stopStreamWatchdog();
    routeCoordinates.clear();
    _lastAcceptedRoutePosition = null;
    _lastUpdateTime = null;
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
    _stopStreamWatchdog();
    _stopwatch.stop();
    _isTracking = false;
    _isPaused = false;
    _lastAcceptedRoutePosition = null;
    _lastUpdateTime = null;

    // Single filtering pipeline: use points already accepted by addCoordinate.
    final cleanCoordinates = List<Map<String, double>>.from(routeCoordinates);

    final distanceMeters = _locationService.calculateDistance(cleanCoordinates);
    final durationSecs = _stopwatch.elapsed.inSeconds;
    final pace = distanceMeters >= 100 ? currentPaceMinPerKm : 0.0;

    return ActivityModel(
      distance: distanceMeters,
      durationSeconds: durationSecs,
      pace: pace,
      date: DateTime.now(),
      routeCoordinates: List<Map<String, double>>.from(cleanCoordinates),
    );
  }

  /// Adds a new GPS position to the route using multi-stage validation.
  /// Filters route points; always updates current marker position (decoupled).
  ///
  /// ✅ Bug 1 fix: Accuracy threshold blocks off-road jumps
  /// ✅ Bug 2 fix: Distance gate prevents stationary drift without freezing
  /// ✅ Bug 3 fix: currentPosition already updated; only route filtering here
  void addCoordinate(Position position) {
    if (!_isTracking || _isPaused) return;

    // Stage 1: Accuracy filter — drop noisy satellite fixes
    if (position.accuracy > _maxAccuracyMeters) {
      debugPrint('[TrackingService] Dropped position: accuracy ${position.accuracy.toStringAsFixed(1)}m > threshold');
      return;
    }

    // Always accept first point
    if (routeCoordinates.isEmpty) {
      routeCoordinates.add({'lat': position.latitude, 'lng': position.longitude});
      _lastAcceptedRoutePosition = position;
      return;
    }

    final last = _lastAcceptedRoutePosition;
    if (last == null) {
      routeCoordinates.add({'lat': position.latitude, 'lng': position.longitude});
      _lastAcceptedRoutePosition = position;
      return;
    }

    // Stage 2: Distance-based filtering (prevents sub-3m jitter)
    final distance = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      position.latitude,
      position.longitude,
    );

    if (distance < _minPointDistanceMeters) {
      // Sub-threshold movement — ignore but don't reject the entire stream
      return;
    }

    // Stage 3: Speed validation (rejects jumps, allows slow movement)
    final timeDiffMs = position.timestamp.difference(last.timestamp).inMilliseconds;
    if (timeDiffMs > 0) {
      final speedMps = distance / (timeDiffMs / 1000.0);
      final sensorSpeedMps = position.speed < 0 ? speedMps : position.speed;

      // When mostly stationary, require bigger movement if accuracy is weak.
      final adaptiveStationaryDistance = (_minPointDistanceMeters +
              (position.accuracy * 0.18).clamp(0.0, 3.5))
          .clamp(_minPointDistanceMeters, 5.5);
      if (sensorSpeedMps < _stationarySpeedMps &&
          distance < adaptiveStationaryDistance) {
        debugPrint(
          '[TrackingService] Dropped position: stationary drift ${distance.toStringAsFixed(1)}m '
          '< ${adaptiveStationaryDistance.toStringAsFixed(1)}m (acc ${position.accuracy.toStringAsFixed(1)}m)',
        );
        return;
      }
      
      // Only reject impossible speeds (> 12 m/s ≈ 43 km/h)
      // Do NOT use speedMps < 0.5 cutoff — causes frozen markers
      if (speedMps > _maxSpeedMps) {
        debugPrint('[TrackingService] Dropped position: speed ${speedMps.toStringAsFixed(1)} m/s exceeds limit');
        return;
      }
    }

    // Stage 4: Accept and optionally smooth
    routeCoordinates.add({'lat': position.latitude, 'lng': position.longitude});
    _lastAcceptedRoutePosition = position;
  }

  void tick() => _notify();

  void dispose() {
    _positionStream?.cancel();
    _ticker?.cancel();
    _stopStreamWatchdog();
  }
}
