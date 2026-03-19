import 'package:geolocator/geolocator.dart';

/// Lightweight GPS noise filtering utilities for tracking paths.

/// Filters coordinates by removing consecutive points below [minDistanceMeters].
/// Default is 2.0m to match tracking service minimum point distance.
List<Map<String, double>> applyMinDistanceFilter(
    List<Map<String, double>> coordinates, {
      double minDistanceMeters = 2.0, // Must match _minPointDistanceMeters in tracking_service
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
    // Only add if distance is >= minimum (strict filter)
    if (distance >= minDistanceMeters) {
      filtered.add(current);
    }
  }

  // Always include the final point to complete the route
  if (filtered.length > 1 && filtered.last != coordinates.last) {
    final distance = Geolocator.distanceBetween(
      filtered.last['lat']!,
      filtered.last['lng']!,
      coordinates.last['lat']!,
      coordinates.last['lng']!,
    );
    if (distance >= minDistanceMeters) {
      filtered.add(coordinates.last);
    }
  }

  return filtered;
}

/// Removes GPS outlier points that are unrealistically far from neighbors.
/// Uses speed-based filtering to detect impossible movements.
/// Also validates consecutive movements to prevent jitter accumulation.
List<Map<String, double>> filterGPSOutliers(
    List<Map<String, double>> coordinates, {
      double maxReasonableSpeedMps = 10.0, // 10 m/s ≈ 36 km/h (safe max for running)
      double timeBetweenPointsSeconds = 1.0,
    }) {
  // Need at least 2 points to process
  if (coordinates.length < 2) return List<Map<String, double>>.from(coordinates);

  final filtered = <Map<String, double>>[coordinates.first];

  for (int i = 1; i < coordinates.length; i++) {
    final current = coordinates[i];
    final last = filtered.last;

    final distance = Geolocator.distanceBetween(
      last['lat']!,
      last['lng']!,
      current['lat']!,
      current['lng']!,
    );

    final impliedSpeedMps = distance / timeBetweenPointsSeconds;

    // FILTER 1: Reject if speed is completely unrealistic
    if (impliedSpeedMps > maxReasonableSpeedMps) {
      continue;
    }

    // FILTER 2: Check neighbors for isolated outlier pattern
    if (i < coordinates.length - 1) {
      final next = coordinates[i + 1];
      final distToNext = Geolocator.distanceBetween(
        current['lat']!,
        current['lng']!,
        next['lat']!,
        next['lng']!,
      );

      final impliedSpeedToNext = distToNext / timeBetweenPointsSeconds;
      // If BOTH speeds are unrealistic, this is an isolated jump -> reject
      if (impliedSpeedToNext > maxReasonableSpeedMps &&
          impliedSpeedMps > maxReasonableSpeedMps) {
        continue;
      }
    }

    // FILTER 3: Reject consecutive tiny movements (< 0.5m each) as jitter
    if (distance < 0.5 && filtered.length >= 2) {
      final prevToLast = Geolocator.distanceBetween(
        filtered[filtered.length - 2]['lat']!,
        filtered[filtered.length - 2]['lng']!,
        last['lat']!,
        last['lng']!,
      );
      // If previous distance was also tiny, skip this accumulating jitter
      if (prevToLast < 0.5) {
        continue;
      }
    }

    // Point passed all filters - add it
    filtered.add(current);
  }

  // BUG FIX: Must return filtered list, NOT original
  // If somehow all points were filtered (shouldn't happen), keep at least start and end
  if (filtered.isEmpty) {
    return [coordinates.first, coordinates.last];
  }

  // Ensure the last point is included
  if (filtered.last != coordinates.last) {
    final distance = Geolocator.distanceBetween(
      filtered.last['lat']!,
      filtered.last['lng']!,
      coordinates.last['lat']!,
      coordinates.last['lng']!,
    );
    if (distance >= 0.0) { // Always include final point
      filtered.add(coordinates.last);
    }
  }

  return filtered;
}

/// Optional 3-point moving average to reduce tiny zig-zag noise.
/// Currently disabled (enabled=false) to preserve accurate route traces.
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