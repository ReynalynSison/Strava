import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/tracking_service.dart';
import '../services/storage_service.dart';
import '../models/activity_model.dart';
import 'activity_summary_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // ─── Services ─────────────────────────────────────────────────────────────
  final LocationService _locationService = LocationService();
  final TrackingService _trackingService = TrackingService();

  // ─── Map ──────────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();

  // ─── State ────────────────────────────────────────────────────────────────
  Position? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;

  // ─── Tracking ─────────────────────────────────────────────────────────────
  StreamSubscription<Position>? _positionStream;
  Timer? _uiTimer;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _uiTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ─── Location Init ────────────────────────────────────────────────────────

  Future<void> _initializeLocation() async {
    final hasPermission = await _locationService.requestPermission();
    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Location permission denied';
      });
      _showPermissionDeniedDialog();
      return;
    }

    try {
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to get location: $e';
      });
    }
  }

  // ─── Tracking Controls ────────────────────────────────────────────────────

  void _startTracking() {
    _trackingService.startTracking();

    // Start GPS position stream
    _positionStream = _locationService.getPositionStream().listen((position) {
      if (!mounted) return;
      _trackingService.addCoordinate(position.latitude, position.longitude);
      setState(() {
        _currentPosition = position;
      });
      // Keep map centered on user
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    });

    // Refresh stats UI every second
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    setState(() {});
  }

  void _pauseTracking() {
    _trackingService.pauseTracking();
    _positionStream?.pause();
    _uiTimer?.cancel();
    setState(() {});
  }

  void _resumeTracking() {
    _trackingService.resumeTracking();
    _positionStream?.resume();

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    setState(() {});
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
            onPressed: () {
              Navigator.pop(context);
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

  void _stopTracking() async {
    // Cancel streams and timers first
    _positionStream?.cancel();
    _positionStream = null;
    _uiTimer?.cancel();
    _uiTimer = null;

    // Get the completed activity from TrackingService
    final ActivityModel activity = _trackingService.stopTracking();
    if (!mounted) return;
    setState(() {});

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

    // Save to Hive
    await StorageService().saveActivity(activity);

    if (!mounted) return;
    // Dismiss the saving dialog
    Navigator.pop(context);

    // Navigate to Activity Summary — use push so Done can pop back to Record tab
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ActivitySummaryScreen(activity: activity),
      ),
    ).then((_) {
      // Clear old route when user returns from summary so map is fresh
      if (mounted) {
        _trackingService.routeCoordinates.clear();
        setState(() {});
      }
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
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
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
    if (_isLoading) return _buildLoading();
    if (_errorMessage != null) return _buildError();
    if (_currentPosition == null) return _buildNoLocation();
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

  Widget _buildError() {
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
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                child: const Text('Retry'),
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializeLocation();
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
    final isTracking = _trackingService.isTracking;
    final isPaused = _trackingService.isPaused;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    // Build polyline from recorded coordinates
    final routePoints = _trackingService.routeCoordinates
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
                _currentPosition!.latitude,
                _currentPosition!.longitude,
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
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
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
                          value: _trackingService.currentDistanceKm < 1
                              ? '${(_trackingService.currentDistanceKm * 1000).toStringAsFixed(0)} m'
                              : '${_trackingService.currentDistanceKm.toStringAsFixed(2)} km',
                        ),
                        _statDivider(),
                        _statTile(
                          label: 'TIME',
                          value: _trackingService.formattedDuration,
                        ),
                        _statDivider(),
                        _statTile(
                          label: 'PACE',
                          value: _trackingService.formattedPace,
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
