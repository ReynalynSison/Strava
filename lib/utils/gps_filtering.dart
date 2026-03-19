import 'package:geolocator/geolocator.dart';

/// Lightweight GPS noise filtering utilities for tracking paths.

/// Filters coordinates by removing consecutive points below [minDistanceMeters].
List<Map<String, double>> applyMinDistanceFilter(
  List<Map<String, double>> coordinates, {
  double minDistanceMeters = 5.0,
}) {
  if (coordinates.isEmpty) return <Map<String, double>>[];
  if (coordinates.length == 1) return List<Map<String, double>>.from(coordinates);

  final filtered = <Map<String, double>>[coordinates.first];
  for (final current in coordinates.skip(1)) {
	final last = filtered.last;
	final distance = Geolocator.distanceBetween(
	  last['lat']!,
	  last['lng']!,
	  current['lat']!,
	  current['lng']!,
	);
	if (distance >= minDistanceMeters) {
	  filtered.add(current);
	}
  }

  if (filtered.last != coordinates.last) {
	filtered.add(coordinates.last);
  }

  return filtered;
}

/// Removes GPS outlier points that are unrealistically far from neighbors.
/// Uses speed-based filtering: if the distance between consecutive points would
/// require an impossible speed (e.g., >50 m/s = 180 km/h), it's probably GPS noise.
/// Also checks if a point is suspiciously far from neighboring points (outlier detection).
List<Map<String, double>> filterGPSOutliers(
  List<Map<String, double>> coordinates, {
  double maxReasonableSpeedMps = 15.0, // 15 m/s ≈ 54 km/h (reasonable max for running)
  double timeBetweenPointsSeconds = 1.0, // Assume 1 second between points on average
}) {
  if (coordinates.length < 3) return List<Map<String, double>>.from(coordinates);

  final filtered = <Map<String, double>>[coordinates.first];

  for (int i = 1; i < coordinates.length; i++) {
	final current = coordinates[i];
	final last = filtered.last;

	// Calculate distance from last accepted point
	final distance = Geolocator.distanceBetween(
	  last['lat']!,
	  last['lng']!,
	  current['lat']!,
	  current['lng']!,
	);

	// Check implied speed (distance / assumed time)
	final impliedSpeedMps = distance / timeBetweenPointsSeconds;

	// Reject if speed is unrealistic (GPS noise/jump)
	if (impliedSpeedMps > maxReasonableSpeedMps) {
	  continue; // Skip this outlier point
	}

	// Additional check: if this point is surrounded by nearby points,
	// and it's far from both neighbors, it's probably an outlier
	if (i < coordinates.length - 1) {
	  final next = coordinates[i + 1];
	  final distToNext = Geolocator.distanceBetween(
		current['lat']!,
		current['lng']!,
		next['lat']!,
		next['lng']!,
	  );

	  // If both distances (to last and to next) are unrealistic, skip it
	  final impliedSpeedToNext = distToNext / timeBetweenPointsSeconds;
	  if (impliedSpeedToNext > maxReasonableSpeedMps && impliedSpeedMps > maxReasonableSpeedMps) {
		continue;
	  }
	}

	filtered.add(current);
  }

  // Always include the last point if it wasn't included
  if (filtered.last != coordinates.last) {
	filtered.add(coordinates.last);
  }

  return filtered;
}

/// Optional 3-point moving average to reduce tiny zig-zag noise.
List<Map<String, double>> applyMovingAverageWindow(
  List<Map<String, double>> coordinates, {
  bool enabled = false,
}) {
  if (!enabled || coordinates.length < 3) {
	return List<Map<String, double>>.from(coordinates);
  }

  final smoothed = <Map<String, double>>[coordinates.first];
  for (int i = 1; i < coordinates.length - 1; i++) {
	final prev = coordinates[i - 1];
	final curr = coordinates[i];
	final next = coordinates[i + 1];
	smoothed.add({
	  'lat': (prev['lat']! + curr['lat']! + next['lat']!) / 3,
	  'lng': (prev['lng']! + curr['lng']! + next['lng']!) / 3,
	});
  }
  smoothed.add(coordinates.last);
  return smoothed;
}

