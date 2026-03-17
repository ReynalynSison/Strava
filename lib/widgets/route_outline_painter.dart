import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../utils/smoothing_utils.dart';

/// Draws the GPS route as an orange outline shape — like Strava activity art.
/// Scales and centres the route path inside the available [Size].
class RouteOutlinePainter extends CustomPainter {
  final List<Map<String, double>> coordinates;

  const RouteOutlinePainter({required this.coordinates});

  @override
  void paint(Canvas canvas, Size size) {
    if (coordinates.isEmpty) return;

    // Single point — draw a plain centred orange dot
    if (coordinates.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(center, 8,
          Paint()..color = const Color(0xFFFC4C02)..style = PaintingStyle.fill);
      canvas.drawCircle(center, 8,
          Paint()..color = CupertinoColors.white..style = PaintingStyle.stroke..strokeWidth = 2);
      return;
    }

    // ── Bounding box ──────────────────────────────────────────────────────
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

    // Uniform scale to keep aspect ratio — fit inside canvas with padding
    const pad = 0.15;
    final drawW = size.width * (1 - pad * 2);
    final drawH = size.height * (1 - pad * 2);

    double scaleX = lngSpan < 1e-9 ? 1 : drawW / lngSpan;
    double scaleY = latSpan < 1e-9 ? 1 : drawH / latSpan;
    final scale = min(scaleX, scaleY);

    final routeW = lngSpan < 1e-9 ? 0.0 : lngSpan * scale;
    final routeH = latSpan < 1e-9 ? 0.0 : latSpan * scale;

    final offX = (size.width - routeW) / 2;
    final offY = (size.height - routeH) / 2;

    Offset toOffset(double lat, double lng) {
      final x = lngSpan < 1e-9 ? size.width / 2 : (lng - minLng) * scale + offX;
      final y = latSpan < 1e-9 ? size.height / 2 : (maxLat - lat) * scale + offY;
      return Offset(x, y);
    }

    // ── Glow paint ────────────────────────────────────────────────────────
    final glowPaint = Paint()
      ..color = const Color(0x44FC4C02)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // ── Main route paint ──────────────────────────────────────────────────
    final routePaint = Paint()
      ..color = const Color(0xFFFC4C02)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final points = coordinates
        .map((c) => toOffset(c['lat']!, c['lng']!))
        .toList(growable: false);
    final path = buildSmoothPath(points);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, routePaint);

    // ── Start dot (green) ─────────────────────────────────────────────────
    final startOff = toOffset(coordinates.first['lat']!, coordinates.first['lng']!);
    canvas.drawCircle(startOff, 5, Paint()..color = CupertinoColors.systemGreen..style = PaintingStyle.fill);
    canvas.drawCircle(startOff, 5, Paint()..color = CupertinoColors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // ── End dot (red) ─────────────────────────────────────────────────────
    final endOff = toOffset(coordinates.last['lat']!, coordinates.last['lng']!);
    canvas.drawCircle(endOff, 5, Paint()..color = CupertinoColors.systemRed..style = PaintingStyle.fill);
    canvas.drawCircle(endOff, 5, Paint()..color = CupertinoColors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(RouteOutlinePainter old) => old.coordinates != coordinates;
}

/// A ready-to-use widget that wraps [RouteOutlinePainter].
class RouteOutlineWidget extends StatelessWidget {
  final List<Map<String, double>> coordinates;
  final double size;

  const RouteOutlineWidget({
    super.key,
    required this.coordinates,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    if (coordinates.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RouteOutlinePainter(coordinates: coordinates),
      ),
    );
  }
}
