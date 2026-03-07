import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity_model.dart';
import '../services/animation_service.dart';
import '../utils/formatters.dart';
import '../widgets/animated_route_widget.dart';

/// Full-screen animated route screen with a live map background.
class AnimatedRouteScreen extends StatefulWidget {
  final ActivityModel activity;

  const AnimatedRouteScreen({super.key, required this.activity});

  @override
  State<AnimatedRouteScreen> createState() => _AnimatedRouteScreenState();
}

class _AnimatedRouteScreenState extends State<AnimatedRouteScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final AnimationService _animationService = AnimationService();
  bool _isSharing = false;

  /// Compute the center of all coordinates for the map initial position.
  LatLng get _center {
    if (widget.activity.routeCoordinates.isEmpty) {
      return const LatLng(0, 0);
    }
    final lats =
        widget.activity.routeCoordinates.map((c) => c['lat']!).toList();
    final lngs =
        widget.activity.routeCoordinates.map((c) => c['lng']!).toList();
    return LatLng(
      (lats.reduce((a, b) => a + b)) / lats.length,
      (lngs.reduce((a, b) => a + b)) / lngs.length,
    );
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      await _animationService.shareAnimationFrame(
        _captureKey,
        text:
            'Just ran ${formatDistance(widget.activity.distance)} in ${formatDuration(widget.activity.durationSeconds)} 🏃 #RunTracker',
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Share Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.7),
        middle: const Text(
          'Animated Route',
          style: TextStyle(color: CupertinoColors.white),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSharing ? null : _share,
          child: _isSharing
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.share,
                  color: CupertinoColors.white),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Map + animation layer ──────────────────────────────
            Expanded(
              child: RepaintBoundary(
                key: _captureKey,
                child: Stack(
                  children: [
                    // ── Static map background ──────────────────────
                    Positioned.fill(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: _mapZoom,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none, // locked for animation
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: tileUrl,
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName:
                                'com.example.strava_like_app',
                            retinaMode:
                                MediaQuery.devicePixelRatioOf(context) > 1.0,
                          ),
                        ],
                      ),
                    ),

                    // ── Animated route drawn on top ────────────────
                    Positioned.fill(
                      child: AnimatedRouteWidget(
                        coordinates: widget.activity.routeCoordinates,
                        distance: widget.activity.distance,
                        durationSeconds: widget.activity.durationSeconds,
                        pace: widget.activity.pace,
                        transparentBackground: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom bar ─────────────────────────────────────────
            Container(
              color: CupertinoColors.black,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tap animation to replay',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    color: CupertinoColors.systemBlue,
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    onPressed: _isSharing ? null : _share,
                    child: _isSharing
                        ? const CupertinoActivityIndicator()
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.share,
                                  color: CupertinoColors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Share',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Estimate appropriate zoom level based on coordinate span.
  double get _mapZoom {
    final coords = widget.activity.routeCoordinates;
    if (coords.length < 2) return 14.0;
    final lats = coords.map((c) => c['lat']!).toList();
    final lngs = coords.map((c) => c['lng']!).toList();
    final latSpan = lats.reduce((a, b) => a > b ? a : b) -
        lats.reduce((a, b) => a < b ? a : b);
    final lngSpan = lngs.reduce((a, b) => a > b ? a : b) -
        lngs.reduce((a, b) => a < b ? a : b);
    final span = latSpan > lngSpan ? latSpan : lngSpan;
    if (span > 0.1) return 11.5;
    if (span > 0.05) return 12.5;
    if (span > 0.02) return 13.5;
    if (span > 0.005) return 14.5;
    return 15.5;
  }
}
