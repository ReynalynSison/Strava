import 'dart:ui';

/// Builds a smooth route path using Catmull-Rom spline interpolation.
///
/// This keeps the route passing through the original points while removing
/// harsh angles from direct point-to-point segments.
Path buildSmoothPath(
  List<Offset> points, {
  int segmentsPerCurve = 8,
}) {
  final path = Path();
  if (points.isEmpty) return path;

  path.moveTo(points.first.dx, points.first.dy);
  if (points.length < 3) {
	for (final p in points.skip(1)) {
	  path.lineTo(p.dx, p.dy);
	}
	return path;
  }

  final safeSegments = segmentsPerCurve.clamp(4, 16);
  for (int i = 0; i < points.length - 1; i++) {
	final p0 = i == 0 ? points[i] : points[i - 1];
	final p1 = points[i];
	final p2 = points[i + 1];
	final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

	for (int step = 1; step <= safeSegments; step++) {
	  final t = step / safeSegments;
	  final t2 = t * t;
	  final t3 = t2 * t;

	  final x = 0.5 *
		  ((2 * p1.dx) +
			  (-p0.dx + p2.dx) * t +
			  (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
			  (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3);
	  final y = 0.5 *
		  ((2 * p1.dy) +
			  (-p0.dy + p2.dy) * t +
			  (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
			  (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3);
	  path.lineTo(x, y);
	}
  }
  return path;
}

/// Applies a tiny moving-average window to reduce visual jitter.
/// Start and end points are preserved for route fidelity.
List<Map<String, double>> applyMovingAverageCoordinates(
  List<Map<String, double>> coordinates, {
  bool enabled = false,
}) {
  if (!enabled || coordinates.length < 3) {
	return List<Map<String, double>>.from(coordinates);
  }

  final smoothed = <Map<String, double>>[coordinates.first];
  for (int i = 1; i < coordinates.length - 1; i++) {
	final a = coordinates[i - 1];
	final b = coordinates[i];
	final c = coordinates[i + 1];
	smoothed.add({
	  'lat': (a['lat']! + b['lat']! + c['lat']!) / 3,
	  'lng': (a['lng']! + b['lng']! + c['lng']!) / 3,
	});
  }
  smoothed.add(coordinates.last);
  return smoothed;
}


