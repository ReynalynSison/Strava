import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';

/// Strava-style animated route widget.
/// The polyline draws itself progressively over [duration].
/// Tap anywhere to replay. Stats fade in once the animation completes.
class AnimatedRouteWidget extends ConsumerStatefulWidget {
  final List<Map<String, double>> coordinates;
  final double distance;
  final int durationSeconds;
  final double pace;
  final Duration animationDuration;
  /// If true, the background is transparent (for use over a map).
  /// If false (default), the background is black (standalone mode).
  final bool transparentBackground;

  /// If false, the stats and replay hint overlays are hidden.
  /// Useful for small cards where the overlay would be cluttered.
  final bool showStatsOverlay;

  const AnimatedRouteWidget({
    super.key,
    required this.coordinates,
    required this.distance,
    required this.durationSeconds,
    required this.pace,
    this.animationDuration = const Duration(seconds: 3),
    this.transparentBackground = false,
    this.showStatsOverlay = true,
  });

  @override
  ConsumerState<AnimatedRouteWidget> createState() => _AnimatedRouteWidgetState();
}

class _AnimatedRouteWidgetState extends ConsumerState<AnimatedRouteWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _routeProgress;
  late final Animation<double> _statsFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _routeProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _statsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replay() {
    _controller.reset();
    _controller.forward();
  }

  /// Smooth end-dot opacity:
  ///   fade OUT over [0.00 → 0.10] when replaying (dissolve on reset)
  ///   fade IN  over [0.80 → 1.00] as line nears the end
  double get _endDotOpacity {
    final raw = _controller.value; // linear 0→1
    if (raw < 0.10) return (1.0 - raw / 0.10).clamp(0.0, 1.0);
    return ((raw - 0.80) / 0.20).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final useMetric = ref.watch(appSettingsProvider).useMetric;
    return GestureDetector(
      onTap: _replay,
      child: Container(
        color: widget.transparentBackground
            ? const Color(0x00000000)
            : CupertinoColors.black,
        child: Stack(
          children: [
            // ── Animated polyline + dots ───────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                // Listen to _controller (linear) NOT _routeProgress so
                // _endDotOpacity sees the raw value for its 0→0.10 window.
                animation: _controller,
                builder: (_, __) => CustomPaint(
                  painter: _AnimatedRoutePainter(
                    coordinates: widget.coordinates,
                    progress: _routeProgress.value,
                    endDotOpacity: _endDotOpacity,
                  ),
                ),
              ),
            ),

            // ── Stats overlay — fades in at end ───────────────────
            if (widget.showStatsOverlay)
              Positioned(
                left: 20,
                bottom: 36,
                child: FadeTransition(
                  opacity: _statsFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatDistance(widget.distance, useMetric: useMetric),
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.white,
                          letterSpacing: -1,
                          shadows: [Shadow(color: Color(0xAA000000), blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatBadge(
                            icon: CupertinoIcons.timer,
                            value: formatDuration(widget.durationSeconds),
                          ),
                          const SizedBox(width: 8),
                          _StatBadge(
                            icon: CupertinoIcons.speedometer,
                            value: formatPace(widget.pace, useMetric: useMetric),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ── Replay hint ────────────────────────────────────────
            if (widget.showStatsOverlay)
              Positioned(
                top: 16,
                right: 16,
                child: AnimatedBuilder(
                  animation: _statsFade,
                  builder: (_, __) => Opacity(
                    opacity: _statsFade.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x55FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.repeat,
                              color: CupertinoColors.white, size: 13),
                          SizedBox(width: 4),
                          Text('Tap to replay',
                              style: TextStyle(
                                  color: CupertinoColors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Animated Route Painter ────────────────────────────────────────────────────

class _AnimatedRoutePainter extends CustomPainter {
  final List<Map<String, double>> coordinates;
  final double progress;      // curved 0→1 — controls how much line is drawn
  final double endDotOpacity; // smooth 0→1 driven by _endDotOpacity getter

  const _AnimatedRoutePainter({
    required this.coordinates,
    required this.progress,
    required this.endDotOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (coordinates.isEmpty) return;

    // Single point — centred orange dot
    if (coordinates.length == 1) {
      if (progress > 0) {
        final center = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(center, 8,
            Paint()..color = CupertinoColors.systemOrange..style = PaintingStyle.fill);
        canvas.drawCircle(center, 8,
            Paint()..color = CupertinoColors.white..style = PaintingStyle.stroke..strokeWidth = 2);
      }
      return;
    }

    // Bounding box
    double minLat = coordinates.first['lat']!;
    double maxLat = coordinates.first['lat']!;
    double minLng = coordinates.first['lng']!;
    double maxLng = coordinates.first['lng']!;
    for (final c in coordinates) {
      minLat = min(minLat, c['lat']!);
      maxLat = max(maxLat, c['lat']!);
      minLng = min(minLng, c['lng']!);
      maxLng = max(maxLng, c['lng']!);
    }

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    const pad = 0.12;
    final drawW = size.width  * (1 - pad * 2);
    final drawH = size.height * (1 - pad * 2);
    final offX  = size.width  * pad;
    final offY  = size.height * pad;

    Offset toOffset(double lat, double lng) => Offset(
      latSpan < 1e-9 ? drawW / 2 : ((lng - minLng) / lngSpan) * drawW + offX,
      latSpan < 1e-9 ? drawH / 2 : ((maxLat - lat) / latSpan) * drawH + offY,
    );

    // Slice visible points
    final total = coordinates.length;
    final count = (total * progress).ceil().clamp(2, total);
    final visible = coordinates.sublist(0, count);

    // Build path
    final path = Path();
    final firstOff = toOffset(visible.first['lat']!, visible.first['lng']!);
    path.moveTo(firstOff.dx, firstOff.dy);
    for (final c in visible.skip(1)) {
      final o = toOffset(c['lat']!, c['lng']!);
      path.lineTo(o.dx, o.dy);
    }

    // Glow
    canvas.drawPath(path, Paint()
      ..color = const Color(0x44FF9500)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke);

    // Main line
    canvas.drawPath(path, Paint()
      ..color = CupertinoColors.systemOrange
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke);

    // Start dot — always visible
    if (progress > 0) {
      final s = toOffset(coordinates.first['lat']!, coordinates.first['lng']!);
      canvas.drawCircle(s, 7, Paint()..color = CupertinoColors.systemGreen..style = PaintingStyle.fill);
      canvas.drawCircle(s, 7, Paint()..color = CupertinoColors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // End dot — smooth fade driven by endDotOpacity (no hard threshold)
    if (endDotOpacity > 0) {
      final e = toOffset(coordinates.last['lat']!, coordinates.last['lng']!);
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
  bool shouldRepaint(_AnimatedRoutePainter old) =>
      old.progress != progress ||
      old.endDotOpacity != endDotOpacity ||
      old.coordinates != coordinates;
}

// ── Stat Badge ────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatBadge({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x55FFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: CupertinoColors.systemOrange),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
