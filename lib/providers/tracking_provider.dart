import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/activity_model.dart';
import '../services/run_notification_service.dart';
import '../services/tracking_service.dart';
import 'app_settings_provider.dart';

class TrackingState {
  final Position? currentPosition;
  final bool isLoading;
  final String? errorMessage;
  final bool isRunning;
  final bool isPaused;
  final List<Map<String, double>> coordinates;
  final double distanceKm;
  final int durationSeconds;
  final double paceMinPerKm;

  const TrackingState({
	required this.currentPosition,
	required this.isLoading,
	required this.errorMessage,
	required this.isRunning,
	required this.isPaused,
	required this.coordinates,
	required this.distanceKm,
	required this.durationSeconds,
	required this.paceMinPerKm,
  });

  const TrackingState.initial()
	  : currentPosition = null,
		isLoading = true,
		errorMessage = null,
		isRunning = false,
		isPaused = false,
		coordinates = const [],
		distanceKm = 0,
		durationSeconds = 0,
		paceMinPerKm = 0;

  String get formattedDuration {
	final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
	final s = (durationSeconds % 60).toString().padLeft(2, '0');
	return '$m:$s';
  }

  String get formattedPace {
	if (paceMinPerKm <= 0 || paceMinPerKm.isNaN || paceMinPerKm.isInfinite) {
	  return "--'--\"";
	}
	final min = paceMinPerKm.floor();
	final sec = ((paceMinPerKm - min) * 60).round().toString().padLeft(2, '0');
	return "$min'$sec\"";
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  final TrackingService _service;
  final RunNotificationService _notificationService;
  final Ref _ref;
  StreamSubscription<RunNotificationAction>? _notificationActionSub;

  TrackingNotifier(this._service, this._notificationService, this._ref)
      : super(const TrackingState.initial()) {
    _service.bind(_emit);
    _notificationActionSub =
        _notificationService.actions.listen(_handleNotificationAction);
    if (_notificationsEnabled) {
      unawaited(_notificationService.initialize());
    }
    _emit();
  }

  void _debug(String message) {
    debugPrint('[TrackingNotifier] $message');
  }

  bool get _notificationsEnabled {
    return _ref.read(appSettingsProvider).runNotificationsEnabled;
  }

  void onRunNotificationPreferenceChanged(bool enabled) {
    if (!enabled) {
      unawaited(_notificationService.cancel());
      return;
    }
    unawaited(_notificationService.initialize());
    _syncNotificationFromState();
  }

  void _emit() {
    state = TrackingState(
      currentPosition: _service.currentPosition,
      isLoading: _service.isLoading,
      errorMessage: _service.errorMessage,
      isRunning: _service.isTracking,
      isPaused: _service.isPaused,
      coordinates: List<Map<String, double>>.from(_service.routeCoordinates),
      distanceKm: _service.currentDistanceKm,
      durationSeconds: _service.elapsedSeconds,
      paceMinPerKm: _service.currentPaceMinPerKm,
    );

    _syncNotificationFromState();
  }

  void _handleNotificationAction(RunNotificationAction action) {
    _debug(
      'notification action received: $action, enabled=$_notificationsEnabled, isRunning=${state.isRunning}, isPaused=${state.isPaused}',
    );
    if (!_notificationsEnabled) {
      _debug('ignored action: notifications disabled in settings');
      return;
    }
    if (!state.isRunning) {
      _debug('ignored action: no active run session');
      return;
    }

    if (action == RunNotificationAction.pause) {
      if (state.isPaused) {
        _debug('ignored action: already paused');
        return;
      }
      _debug('action => pauseRun()');
      pauseRun();
      return;
    }

    if (action == RunNotificationAction.resume) {
      if (!state.isPaused) {
        _debug('ignored action: already running');
        return;
      }
      _debug('action => resumeRun()');
      resumeRun();
      return;
    }

    _debug('ignored action: unsupported action type');
  }

  void _syncNotificationFromState() {
    if (!_notificationsEnabled) {
      unawaited(_notificationService.cancel());
      return;
    }

    if (!state.isRunning) return;

    if (state.isPaused) {
      unawaited(
        _notificationService.showPaused(
          distanceKm: state.distanceKm,
          durationSeconds: state.durationSeconds,
          paceMinPerKm: state.paceMinPerKm,
        ),
      );
      return;
    }

    unawaited(
      _notificationService.showRunning(
        distanceKm: state.distanceKm,
        durationSeconds: state.durationSeconds,
        paceMinPerKm: state.paceMinPerKm,
      ),
    );
  }

  Future<void> initializeLocation() => _service.initializeLocation();

  Future<void> openLocationSettings() => _service.openLocationSettings();

  void startRun() {
    _debug('startRun()');
    _service.startTracking();
  }

  void pauseRun() {
    _debug('pauseRun()');
    _service.pauseTracking();
  }

  void resumeRun() {
    _debug('resumeRun()');
    _service.resumeTracking();
  }

  ActivityModel stopRun() {
    _debug('stopRun()');
    final activity = _service.stopTracking();
    unawaited(_notificationService.cancel());
    _emit();
    return activity;
  }

  void addCoordinate(double lat, double lng) {
    _service.addCoordinate(lat, lng);
    _emit();
  }

  void tick() {
    _service.tick();
  }

  void clearRoute() {
    _service.resetSession();
    unawaited(_notificationService.cancel());
    _emit();
  }

  @override
  void dispose() {
    _notificationActionSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  final notifier =
      TrackingNotifier(TrackingService(), RunNotificationService.instance, ref);

  ref.listen<AppSettingsState>(appSettingsProvider, (previous, next) {
    if (previous?.runNotificationsEnabled == next.runNotificationsEnabled) {
      return;
    }
    notifier.onRunNotificationPreferenceChanged(next.runNotificationsEnabled);
  });

  return notifier;
});

