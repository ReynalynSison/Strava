import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../utils/formatters.dart';

/// Strava-style animated route widget.
/// The polyline draws itself progressively over [duration].
/// Tap anywhere to replay. Stats fade in once the animation completes.
class AnimatedRouteWidget extends StatefulWidget {
  final List<Map<String, double>> coordinates;
  final double distance;
  final int durationSeconds;
  final double pace;
  final Duration animationDuration;
  /// If true, the background is transparent (for use over a map).
  /// If false (default), the background is black (standalone mode).
  final bool transparentBackground;

  const AnimatedRouteWidget({
    super.key,
    required this.coordinates,
    required this.distance,
    required this.durationSeconds,
    required this.pace,
    this.animationDuration = const Duration(seconds: 3),
    this.transparentBackground = false,
  });

  @override
  State<AnimatedRouteWidget> createState() => _AnimatedRouteWidgetState();
}

class _AnimatedRouteWidgetState extends State<AnimatedRouteWidget>
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

    // Route draws from 0 → 1 over the full duration
    _routeProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Stats fade in over the last 30% of the animation
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _replay,
      child: Container(
        color: widget.transparentBackground
            ? const Color(0x00000000) // fully transparent over map
            : CupertinoColors.black,
        child: Stack(
          children: [
            // ── Animated polyline ──────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _routeProgress,
                builder: (_, __) => CustomPaint(
                  painter: _AnimatedRoutePainter(
                    coordinates: widget.coordinates,
                    progress: _routeProgress.value,
                  ),
                ),
              ),
            ),

            // ── Stats overlay — fades in at end ───────────────────
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
                      formatDistance(widget.distance),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.white,
                        letterSpacing: -1,
                        shadows: [
                          Shadow(
                            color: Color(0xAA000000),
                            blurRadius: 8,
                          ),
                        ],
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
                          value: formatPace(widget.pace),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Replay hint — shown after animation completes ─────
            Positioned(
              top: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _statsFade,
                builder: (_, __) => Opacity(
                  opacity: _statsFade.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
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
                        Text(
                          'Tap to replay',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 12,
                          ),
                        ),
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
  final double progress; // 0.0 → 1.0

  const _AnimatedRoutePainter({
    required this.coordinates,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (coordinates.length < 2) return;

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
    final drawW = size.width * (1 - pad * 2);
    final drawH = size.height * (1 - pad * 2);
    final offX = size.width * pad;
    final offY = size.height * pad;

    Offset toOffset(double lat, double lng) {
      final x = latSpan < 1e-9
          ? drawW / 2
          : ((lng - minLng) / lngSpan) * drawW + offX;
      final y = latSpan < 1e-9
          ? drawH / 2
          : ((maxLat - lat) / latSpan) * drawH + offY;
      return Offset(x, y);
    }

    // How many points to draw based on progress
    final totalPoints = coordinates.length;
    final visibleCount =
        (totalPoints * progress).ceil().clamp(2, totalPoints);
    final visible = coordinates.sublist(0, visibleCount);

    // Draw glow
    final glowPaint = Paint()
      ..color = const Color(0x44FF9500)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw route
    final routePaint = Paint()
      ..color = CupertinoColors.systemOrange
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final firstOff = toOffset(visible.first['lat']!, visible.first['lng']!);
    path.moveTo(firstOff.dx, firstOff.dy);
    for (final c in visible.skip(1)) {
      final o = toOffset(c['lat']!, c['lng']!);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, routePaint);

    // Start dot (always visible once any progress)
    if (progress > 0) {
      final startOff =
          toOffset(coordinates.first['lat']!, coordinates.first['lng']!);
      canvas.drawCircle(
          startOff,
          7,
          Paint()
            ..color = CupertinoColors.systemGreen
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          startOff,
          7,
          Paint()
            ..color = CupertinoColors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // End dot (only when animation is near complete)
    if (progress > 0.95) {
      final opacity = ((progress - 0.95) / 0.05).clamp(0.0, 1.0);
      final endOff =
          toOffset(coordinates.last['lat']!, coordinates.last['lng']!);
      canvas.drawCircle(
          endOff,
          7,
          Paint()
            ..color =
                CupertinoColors.systemRed.withValues(alpha: opacity)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          endOff,
          7,
          Paint()
            ..color = CupertinoColors.white.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_AnimatedRoutePainter old) =>
      old.progress != progress || old.coordinates != coordinates;
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

