import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../models/activity_model.dart';
import '../utils/formatters.dart';

/// A transparent-background sticker widget that draws the route polyline
/// via [CustomPaint] and overlays distance + pace in white text.
///
/// Designed to be captured by [ShareService.exportTransparentSticker].
/// The root is fully transparent so the exported PNG has no background.
class StickerOverlayWidget extends StatelessWidget {
  final ActivityModel activity;

  /// Width and height of the sticker (square).
  final double size;

  const StickerOverlayWidget({
    super.key,
    required this.activity,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // ── Route polyline via CustomPaint ──────────────────────
          CustomPaint(
            size: Size(size, size),
            painter: _RoutePainter(
              coordinates: activity.routeCoordinates,
            ),
          ),

          // ── Stats overlay ───────────────────────────────────────
          Positioned(
            left: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShadowText(
                  formatDistance(activity.distance),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
                const SizedBox(height: 2),
                _ShadowText(
                  formatPace(activity.pace),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route Painter ─────────────────────────────────────────────────────────────

class _RoutePainter extends CustomPainter {
  final List<Map<String, double>> coordinates;

  const _RoutePainter({required this.coordinates});

  @override
  void paint(Canvas canvas, Size size) {
    if (coordinates.length < 2) return;

    // Compute bounding box
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

    // Padding as fraction of canvas
    const padding = 0.1;
    final drawW = size.width * (1 - padding * 2);
    final drawH = size.height * (1 - padding * 2);
    final offsetX = size.width * padding;
    final offsetY = size.height * padding;

    // Map lat/lng → canvas coordinates
    Offset toOffset(double lat, double lng) {
      final x = latSpan < 1e-9
          ? drawW / 2
          : ((lng - minLng) / lngSpan) * drawW + offsetX;
      // Latitude increases upward, canvas y increases downward → flip
      final y = latSpan < 1e-9
          ? drawH / 2
          : ((maxLat - lat) / latSpan) * drawH + offsetY;
      return Offset(x, y);
    }

    // White glow / shadow pass
    final glowPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Orange route pass
    final routePaint = Paint()
      ..color = CupertinoColors.systemOrange
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = coordinates.first;
    path.moveTo(
      toOffset(first['lat']!, first['lng']!).dx,
      toOffset(first['lat']!, first['lng']!).dy,
    );
    for (final c in coordinates.skip(1)) {
      final o = toOffset(c['lat']!, c['lng']!);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, routePaint);

    // Start dot — green
    final startOffset = toOffset(first['lat']!, first['lng']!);
    canvas.drawCircle(startOffset, 6,
        Paint()..color = CupertinoColors.systemGreen);
    canvas.drawCircle(startOffset, 6,
        Paint()
          ..color = CupertinoColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // End dot — red
    final last = coordinates.last;
    final endOffset = toOffset(last['lat']!, last['lng']!);
    canvas.drawCircle(endOffset, 6,
        Paint()..color = CupertinoColors.systemRed);
    canvas.drawCircle(endOffset, 6,
        Paint()
          ..color = CupertinoColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.coordinates != coordinates;
}

// ── Shadow Text ───────────────────────────────────────────────────────────────

/// White text with a dark drop shadow for readability on any background.
class _ShadowText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const _ShadowText(
    this.text, {
    required this.fontSize,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: CupertinoColors.white,
        shadows: const [
          Shadow(
            color: Color(0xAA000000),
            offset: Offset(0, 1),
            blurRadius: 6,
          ),
          Shadow(
            color: Color(0x66000000),
            offset: Offset(1, 2),
            blurRadius: 12,
          ),
        ],
      ),
    );
  }
}

