import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable map widget that renders a recorded route using CartoDB tiles.
///
/// [interactive] = false → locked map for cards/thumbnails (no pan/zoom).
/// [interactive] = true  → full pan/zoom for Summary screen.
/// [animate]     = true  → polyline draws itself progressively; tap to replay.
/// [showEndMarkers] = false → hide start/end dots (e.g. when stacking overlays).
class RouteMapWidget extends StatefulWidget {
  final List<Map<String, double>> coordinates;
  final bool interactive;
  final double height;
  final bool showEndMarkers;

  /// When true the polyline animates in on load and can be replayed by tapping.
  final bool animate;

  /// Duration of the draw-in animation (only used when [animate] = true).
  final Duration animationDuration;

  const RouteMapWidget({
    super.key,
    required this.coordinates,
    this.interactive = true,
    this.height = 220,
    this.showEndMarkers = true,
    this.animate = false,
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _animController;
  Animation<double>? _progress;
  bool _animDone = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.animate && widget.coordinates.length >= 2) {
      _animController = AnimationController(
        vsync: this,
        duration: widget.animationDuration,
      );
      _progress = CurvedAnimation(
        parent: _animController!,
        curve: Curves.easeInOut,
      );
      _animController!.addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _animDone = true);
        }
      });
      _animController!.forward();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _animController?.dispose();
    super.dispose();
  }

  void _replay() {
    setState(() => _animDone = false);
    _animController?.reset();
    _animController?.forward();
  }

  ({LatLng center, double zoom}) _fitBounds(List<LatLng> points, Size viewport) {
    if (points.isEmpty) return (center: const LatLng(0, 0), zoom: 13.0);
    if (points.length == 1) {
      final zoom = widget.interactive ? 18.0 : 17.2;
      return (center: points.first, zoom: zoom);
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    // Viewport-aware fit so tiny runs are still visible as a line, not two dots.
    final width = viewport.width.clamp(120.0, 1400.0);
    final height = viewport.height.clamp(120.0, 1400.0);
    const tileSize = 256.0;
    const paddingFactor = 0.78; // keep route away from edges

    final latFraction = (_latRad(maxLat) - _latRad(minLat)).abs() / math.pi;
    final lngDiff = (maxLng - minLng).abs();
    final lngFraction = ((lngDiff > 180 ? 360 - lngDiff : lngDiff) / 360)
        .clamp(1e-9, 1.0);

    final latZoom = _zoomForFraction(height * paddingFactor, latFraction, tileSize);
    final lngZoom = _zoomForFraction(width * paddingFactor, lngFraction, tileSize);
    double zoom = math.min(latZoom, lngZoom);

    final maxZoom = widget.interactive ? 19.2 : 18.6;
    final minZoom = widget.interactive ? 10.0 : 9.5;
    zoom = zoom.clamp(minZoom, maxZoom);

    return (center: LatLng(centerLat, centerLng), zoom: zoom);
  }

  double _latRad(double lat) {
    final sinValue = math.sin(lat * math.pi / 180);
    final radX2 = math.log((1 + sinValue) / (1 - sinValue)) / 2;
    return radX2.clamp(-math.pi, math.pi);
  }

  double _zoomForFraction(double mapPx, double fraction, double tileSize) {
    final safeFraction = fraction.clamp(1e-9, 1.0);
    return math.log(mapPx / tileSize / safeFraction) / math.ln2;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    // ── No GPS recorded — orange dot placeholder card ─────────────────────────
    if (widget.coordinates.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: widget.height,
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: CupertinoColors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemOrange.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Stationary',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final points =
        widget.coordinates.map((c) => LatLng(c['lat']!, c['lng']!)).toList();
    final isSinglePoint = points.length == 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fit = _fitBounds(
              points,
              Size(constraints.maxWidth, constraints.maxHeight),
            );
            return Stack(
              children: [
            // ── Static map — built ONCE, never rebuilt by the animation ──────
            // The polyline/markers are drawn on top via CustomPaint overlay,
            // NOT inside FlutterMap children, to avoid full FlutterMap rebuilds.
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: fit.center,
                initialZoom: fit.zoom,
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.strava_like_app',
                  retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.0,
                ),
              ],
            ),

            // ── Animated route overlay — CustomPaint, not inside FlutterMap ──
            // This way the map tiles stay stable while the route animates.
            if (!isSinglePoint)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _progress ?? const AlwaysStoppedAnimation(1.0),
                  builder: (_, __) {
                    final rawProgress = _progress?.value ?? 1.0;

                    // Smooth end-dot: fade IN 0.80→1.00, fade OUT 0.00→0.10 on replay
                    final double endDotOpacity;
                    if (rawProgress < 0.10) {
                      endDotOpacity = (1.0 - rawProgress / 0.10).clamp(0.0, 1.0);
                    } else {
                      endDotOpacity = ((rawProgress - 0.80) / 0.20).clamp(0.0, 1.0);
                    }

                    return CustomPaint(
                      painter: _RouteOverlayPainter(
                        points: points,
                        progress: rawProgress,
                        endDotOpacity: endDotOpacity,
                        mapController: _mapController,
                        strokeWidth: widget.interactive ? 4.0 : 3.0,
                        glowWidth: widget.interactive ? 10.0 : 7.0,
                      ),
                    );
                  },
                ),
              ),

            // ── Single GPS point — orange dot on map ─────────────────────────
            if (isSinglePoint && widget.showEndMarkers)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SingleDotPainter(),
                  ),
                ),
              ),

            // ── Replay button — shown after animation completes ──────────────
            if (widget.animate && _animDone)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: _replay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.repeat,
                            color: CupertinoColors.white, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Replay',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Route Overlay Painter ─────────────────────────────────────────────────────
// Draws the animated polyline + start/end dots on top of the static FlutterMap.
// Projects LatLng → screen pixel using the MapController's camera.

class _RouteOverlayPainter extends CustomPainter {
  final List<LatLng> points;
  final double progress;
  final double endDotOpacity;
  final MapController mapController;
  final double strokeWidth;
  final double glowWidth;

  const _RouteOverlayPainter({
    required this.points,
    required this.progress,
    required this.endDotOpacity,
    required this.mapController,
    required this.strokeWidth,
    required this.glowWidth,
  });

  Offset _project(LatLng latLng) {
    final pt = mapController.camera.latLngToScreenPoint(latLng);
    return Offset(pt.x, pt.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Visible slice based on progress
    final count = (points.length * progress).ceil().clamp(2, points.length);
    final visible = points.sublist(0, count);

    // ui.Path to avoid collision with latlong2's Path<T>
    final path = ui.Path();
    final first = _project(visible.first);
    path.moveTo(first.dx, first.dy);
    for (final p in visible.skip(1)) {
      final o = _project(p);
      path.lineTo(o.dx, o.dy);
    }

    // Glow
    canvas.drawPath(path, Paint()
      ..color = const Color(0x55FC4C02)
      ..strokeWidth = glowWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke);

    // Main line
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFFC4C02)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke);

    // Start dot — always visible
    if (progress > 0) {
      final s = _project(points.first);
      canvas.drawCircle(s, 7, Paint()..color = CupertinoColors.systemGreen..style = PaintingStyle.fill);
      canvas.drawCircle(s, 7, Paint()..color = CupertinoColors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // End dot — smooth opacity
    if (endDotOpacity > 0) {
      final e = _project(points.last);
      canvas.drawCircle(e, 7, Paint()
        ..color = CupertinoColors.systemRed.withValues(alpha: endDotOpacity)
        ..style = PaintingStyle.fill);
      canvas.drawCircle(e, 7, Paint()
        ..color = CupertinoColors.white.withValues(alpha: endDotOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_RouteOverlayPainter old) =>
      old.progress != progress || old.endDotOpacity != endDotOpacity;
}

// ── Single Dot Painter ────────────────────────────────────────────────────────

class _SingleDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 9, Paint()..color = CupertinoColors.systemOrange..style = PaintingStyle.fill);
    canvas.drawCircle(center, 9, Paint()..color = CupertinoColors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_SingleDotPainter old) => false;
}
