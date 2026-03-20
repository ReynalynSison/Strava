import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum RunNotificationAction {
  pause,
  resume,
}

/// Handles run-session notifications independently from tracking logic.
///
/// Action buttons use [showsUserInterface: true] so Android delivers taps via
/// [onDidReceiveNotificationResponse] — the only fully-reliable cross-device
/// path in flutter_local_notifications v17. No new screen is ever pushed;
/// the app surfaces briefly, processes the state change, and the notification
/// updates in-place.
class RunNotificationService {
  RunNotificationService._();

  static final RunNotificationService instance = RunNotificationService._();

  static const int _notificationId = 20260314;
  static const String _channelId = 'run_session_channel';
  static const String _channelName = 'Run Session';
  static const String _channelDescription =
      'Shows an ongoing run with quick controls.';
  static const String _pauseActionId = 'pause_run';
  static const String _resumeActionId = 'resume_run';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<RunNotificationAction> _actionController =
      StreamController<RunNotificationAction>.broadcast();

  bool _initialized = false;
  bool _permissionRequested = false;

  Stream<RunNotificationAction> get actions => _actionController.stream;

  void _debug(String message) {
    debugPrint('[RunNotificationService] $message');
  }

  Future<void> initialize() async {
    if (_initialized) {
      _debug('initialize skipped: already initialized');
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _debug('initialized');
    _initialized = true;
  }

  Future<void> showRunning({
    required double distanceKm,
    required int durationSeconds,
    required double paceMinPerKm,
  }) {
    return _show(
      paused: false,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      paceMinPerKm: paceMinPerKm,
    );
  }

  Future<void> showPaused({
    required double distanceKm,
    required int durationSeconds,
    required double paceMinPerKm,
  }) {
    return _show(
      paused: true,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      paceMinPerKm: paceMinPerKm,
    );
  }

  Future<void> cancel() async {
    await initialize();
    _debug('cancel notification id=$_notificationId');
    await _plugin.cancel(_notificationId);
  }

  Future<void> _show({
    required bool paused,
    required double distanceKm,
    required int durationSeconds,
    required double paceMinPerKm,
  }) async {
    await initialize();
    await _requestPermissionsIfNeeded();

    final statusLine = paused ? 'Run paused' : 'Run in progress';
    final actionLabel = paused ? 'RESUME' : 'PAUSE';
    final actionId = paused ? _resumeActionId : _pauseActionId;
    final statsLine =
        '${_formatDuration(durationSeconds)} · ${distanceKm.toStringAsFixed(2)} km · ${_formatPace(paceMinPerKm)}';
    final content = '$statusLine\n$statsLine';
    _debug('show paused=$paused action=$actionLabel stats="$statsLine"');

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        styleInformation: BigTextStyleInformation(content),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            actionId,
            actionLabel,
            cancelNotification: false,
            showsUserInterface: true, // bring app to foreground → onDidReceiveNotificationResponse fires
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
        subtitle: paused ? 'Run paused' : 'Run in progress',
        categoryIdentifier: 'RUN_SESSION',
      ),
    );

    await _plugin.show(
      _notificationId,
       'Strivo',
      statsLine,
      details,
      payload: paused ? 'paused' : 'running',
    );
  }

  Future<void> _requestPermissionsIfNeeded() async {
    if (_permissionRequested) return;

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: false, sound: false);

    _permissionRequested = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _debug(
      'action callback: id=${response.actionId}, type=${response.notificationResponseType}',
    );
    _emitActionFromId(response.actionId);
  }

  void _emitActionFromId(String? actionId) {
    if (actionId == _pauseActionId) {
      _debug('emitting action=pause');
      _actionController.add(RunNotificationAction.pause);
      return;
    }
    if (actionId == _resumeActionId) {
      _debug('emitting action=resume');
      _actionController.add(RunNotificationAction.resume);
      return;
    }
    _debug('ignored notification tap: id=$actionId (notification body tap)');
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm <= 0 || paceMinPerKm.isNaN || paceMinPerKm.isInfinite) {
      return "--'--\" /km";
    }
    final min = paceMinPerKm.floor();
    final sec = ((paceMinPerKm - min) * 60).round().toString().padLeft(2, '0');
    return "$min'$sec\" /km";
  }

  void dispose() {
    _debug('dispose called');
    _actionController.close();
  }
}





