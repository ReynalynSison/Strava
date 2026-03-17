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

