import '../utils/formatters.dart' as legacy;

/// Facade wrapper around existing formatter functions.
///
/// This keeps current formatting behavior exactly the same while giving
/// provider-driven screens a single object to pass around.
class AppFormatters {
  final bool useMetric;

  const AppFormatters({required this.useMetric});

  String distance(double meters) {
	return legacy.formatDistance(meters, useMetric: useMetric);
  }

  String pace(double paceMinPerKm) {
	return legacy.formatPace(paceMinPerKm, useMetric: useMetric);
  }

  String duration(int seconds) {
	return legacy.formatDuration(seconds);
  }

  String date(DateTime date) {
	return legacy.formatDate(date);
  }
}

