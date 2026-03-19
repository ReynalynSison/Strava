import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/app_providers.dart';
import '../models/activity_model.dart';
import 'activity_summary_screen.dart';
import 'run_photo_screen.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  // ─── Map ──────────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  bool _didShowPermissionDialog = false;
  late final ProviderSubscription<TrackingState> _trackingSub;

  static const double _minDistanceKmForDirectSave = 0.1; // 100 m
  static const int _minDurationSecsForDirectSave = 60;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _trackingSub = ref.listenManual<TrackingState>(
      trackingProvider,
      (previous, next) {
        final prevPos = previous?.currentPosition;
        final nextPos = next.currentPosition;

        if (next.errorMessage == 'Location permission denied' &&
            !_didShowPermissionDialog) {
          _didShowPermissionDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showPermissionDeniedDialog();
          });
        }

        if (nextPos != null &&
            (prevPos == null ||
                prevPos.latitude != nextPos.latitude ||
                prevPos.longitude != nextPos.longitude)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _mapController.move(
              LatLng(nextPos.latitude, nextPos.longitude),
              _mapController.camera.zoom,
            );
          });
        }
      },
    );
    Future.microtask(() => ref.read(trackingProvider.notifier).initializeLocation());
  }

  @override
  void dispose() {
    _trackingSub.close();
    _mapController.dispose();
    super.dispose();
  }

  // ─── Tracking Controls ────────────────────────────────────────────────────

  void _startTracking() {
    ref.read(trackingProvider.notifier).startRun();
  }

  void _pauseTracking() {
    ref.read(trackingProvider.notifier).pauseRun();
  }

  void _resumeTracking() {
    ref.read(trackingProvider.notifier).resumeRun();
  }

  void _showStopConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Stop Run?'),
        content: const Text('Are you sure you want to end this run?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Stop'),
            onPressed: () async {
              Navigator.pop(context);
              final shouldProceed = await _handleShortRunGuardBeforeStop();
              if (!shouldProceed || !mounted) return;
              _stopTracking();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Keep Going'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleShortRunGuardBeforeStop() async {
    final trackingState = ref.read(trackingProvider);
    final isShortOrStationary =
        trackingState.distanceKm < _minDistanceKmForDirectSave ||
        trackingState.durationSeconds < _minDurationSecsForDirectSave;

    if (!isShortOrStationary) return true;

    final decision = await showCupertinoDialog<_ShortRunDecision>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Very Short Run'),
        content: const Text(
          'This run is very short and may be accidental.\n\n'
          'You can keep running, discard it, or save anyway.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Discard Run'),
            onPressed: () => Navigator.pop(ctx, _ShortRunDecision.discard),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Continue Running'),
            onPressed: () => Navigator.pop(ctx, _ShortRunDecision.continueRun),
          ),
          CupertinoDialogAction(
            child: const Text('Save Anyway'),
            onPressed: () => Navigator.pop(ctx, _ShortRunDecision.saveAnyway),
          ),
        ],
      ),
    );

    if (!mounted) return false;

    switch (decision) {
      case _ShortRunDecision.saveAnyway:
        return true;
      case _ShortRunDecision.discard:
        ref.read(trackingProvider.notifier).clearRoute();
        return false;
      case _ShortRunDecision.continueRun:
        final state = ref.read(trackingProvider);
        if (state.isPaused) {
          ref.read(trackingProvider.notifier).resumeRun();
        }
        return false;
      case null:
        return false;
    }
  }

  void _stopTracking() async {
    // Get the completed activity from tracking provider/service.
    ActivityModel activity = ref.read(trackingProvider.notifier).stopRun();
    if (!mounted) return;

    // ── Step 1: Take a post-run photo ──────────────────────────────────────
    final File? photo = await Navigator.push<File?>(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => RunPhotoScreen(activity: activity),
      ),
    );

    if (!mounted) return;

    // Attach the photo path if the user took/chose one
    if (photo != null) {
      activity = activity.copyWith(photoPath: photo.path);
    }

    // ── Step 2: Ask user: post to feed? ────────────────────────────────────
    final TextEditingController captionController = TextEditingController();
    bool postToFeed = false;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: CupertinoTheme.of(ctx).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Handle ────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Run Saved! 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Would you like to post this run to your Feed?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Toggle ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Post to Feed',
                        style: TextStyle(fontSize: 16),
                      ),
                      CupertinoSwitch(
                        value: postToFeed,
                        activeTrackColor: const Color(0xFF2424EA),
                        onChanged: (v) => setSheetState(() => postToFeed = v),
                      ),
                    ],
                  ),
                  // ── Caption field (only when toggled on) ──────────
                  if (postToFeed) ...[
                    const SizedBox(height: 14),
                    CupertinoTextField(
                      controller: captionController,
                      placeholder: 'Add a caption… (optional)',
                      maxLines: 3,
                      minLines: 2,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  // ── Confirm Button ────────────────────────────────
                  CupertinoButton(
                    color: const Color(0xFF2424EA),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      postToFeed ? 'Post & Continue' : 'Continue',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Apply feed flag + caption to activity before saving
    activity = activity.copyWith(
      postedToFeed: postToFeed,
      caption: postToFeed && captionController.text.trim().isNotEmpty
          ? captionController.text.trim()
          : null,
    );

    if (!mounted) return;

    // Show saving indicator
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 12),
            Text('Saving your run...'),
          ],
        ),
      ),
    );

    // Save via provider so app-wide activity state updates immediately.
    await ref.read(activityProvider.notifier).addActivity(activity);

    if (!mounted) return;
    Navigator.pop(context); // dismiss saving dialog

    // Navigate to Activity Summary
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ActivitySummaryScreen(activity: activity),
      ),
    ).then((_) {
      ref.read(trackingProvider.notifier).clearRoute();
    });
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  void _showPermissionDeniedDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location access to track your runs. '
          'Please enable location services in Settings.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Open Settings'),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(trackingProvider.notifier).openLocationSettings();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);


    if (trackingState.isLoading) return _buildLoading();
    if (trackingState.errorMessage != null) {
      return _buildError(trackingState.errorMessage!);
    }
    if (trackingState.currentPosition == null) return _buildNoLocation();
    return _buildMap();
  }

  // ─── Loading State ────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Record')),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 20),
            SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error State ──────────────────────────────────────────────────────────

  Widget _buildError(String errorMessage) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Record')),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.location_slash,
                  size: 64, color: CupertinoColors.systemRed),
              const SizedBox(height: 16),
              Text(errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                child: const Text('Retry'),
                onPressed: () {
                  _didShowPermissionDialog = false;
                  ref.read(trackingProvider.notifier).initializeLocation();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoLocation() {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Record')),
      child: Center(child: Text('No location data')),
    );
  }

  // ─── Main Map View ────────────────────────────────────────────────────────

  Widget _buildMap() {
    final trackingState = ref.watch(trackingProvider);
    final isTracking = trackingState.isRunning;
    final isPaused = trackingState.isPaused;
    final currentPosition = trackingState.currentPosition!;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    // Build polyline from recorded coordinates
    final routePoints = trackingState.coordinates
        .map((c) => LatLng(c['lat']!, c['lng']!))
        .toList();

    return CupertinoPageScaffold(
      // No nav bar — map is full screen
      child: Stack(
        children: [
          // ── Full Screen Map ──────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                currentPosition.latitude,
                currentPosition.longitude,
              ),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.strava_like_app',
                retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.0,
              ),

              // Route polyline
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: CupertinoColors.systemOrange,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),

              // Current position marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      currentPosition.latitude,
                      currentPosition.longitude,
                    ),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBlue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CupertinoColors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  // Start marker (green dot)
                  if (routePoints.isNotEmpty)
                    Marker(
                      point: routePoints.first,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: CupertinoColors.systemGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Stats Overlay (top) ──────────────────────────────────────
          if (isTracking)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(context).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statTile(
                          label: 'DISTANCE',
                          value: trackingState.distanceKm < 1
                              ? '${(trackingState.distanceKm * 1000).toStringAsFixed(0)} m'
                              : '${trackingState.distanceKm.toStringAsFixed(2)} km',
                        ),
                        _statDivider(),
                        _statTile(
                          label: 'TIME',
                          value: trackingState.formattedDuration,
                        ),
                        _statDivider(),
                        _statTile(
                          label: 'PACE',
                          value: trackingState.formattedPace,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Paused Banner ────────────────────────────────────────────
          if (isPaused)
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PAUSED',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),

          // ── Control Buttons (bottom) ─────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: !isTracking
                    // ── Start Button ──────────────────────────────────
                    ? CupertinoButton(
                        color: CupertinoColors.systemGreen,
                        borderRadius: BorderRadius.circular(50),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        onPressed: _startTracking,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.play_fill,
                                color: CupertinoColors.white),
                            SizedBox(width: 8),
                            Text(
                              'Start Run',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    // ── Pause / Stop Row ──────────────────────────────
                    : Row(
                        children: [
                          // Stop
                          CupertinoButton(
                            color: CupertinoColors.systemRed,
                            borderRadius: BorderRadius.circular(50),
                            padding: const EdgeInsets.all(18),
                            onPressed: _showStopConfirmation,
                            child: const Icon(CupertinoIcons.stop_fill,
                                color: CupertinoColors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          // Pause / Resume
                          Expanded(
                            child: CupertinoButton(
                              color: isPaused
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemOrange,
                              borderRadius: BorderRadius.circular(50),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              onPressed: isPaused
                                  ? _resumeTracking
                                  : _pauseTracking,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isPaused
                                        ? CupertinoIcons.play_fill
                                        : CupertinoIcons.pause_fill,
                                    color: CupertinoColors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isPaused ? 'Resume' : 'Pause',
                                    style: const TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat Tile Helper ─────────────────────────────────────────────────────

  Widget _statTile({required String label, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      height: 36,
      width: 1,
      color: CupertinoColors.separator,
    );
  }
}

enum _ShortRunDecision {
  saveAnyway,
  discard,
  continueRun,
}
