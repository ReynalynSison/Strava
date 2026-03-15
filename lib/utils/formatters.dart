/// Pure formatting functions used across the app.
/// Unit-sensitive functions accept [useMetric] so they stay storage-agnostic.

// ─── Distance ─────────────────────────────────────────────────────────────────

/// Formats meters into a readable distance string.
/// Metric:   450 → "450 m"  |  3420 → "3.42 km"
/// Imperial: 450 → "0.28 mi"  |  3420 → "2.12 mi"
String formatDistance(double meters, {bool useMetric = true}) {
  if (useMetric) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  } else {
    final miles = meters / 1609.344;
    return '${miles.toStringAsFixed(2)} mi';
  }
}

// ─── Duration ─────────────────────────────────────────────────────────────────

/// Formats seconds into mm:ss or Xh XXm for long runs.
/// e.g. 1395 → "23:15"  |  4500 → "1h 15m"
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ─── Pace ─────────────────────────────────────────────────────────────────────

/// Formats pace to X'XX"/km (metric) or X'XX"/mi (imperial).
/// e.g. 6.8 min/km → "6'48\"/km"
String formatPace(double paceMinPerKm, {bool useMetric = true}) {
  if (paceMinPerKm <= 0 || paceMinPerKm.isInfinite || paceMinPerKm.isNaN) {
    return "--'--\"";
  }
  double pace = paceMinPerKm;
  String unit = '/km';
  if (!useMetric) {
    // Convert min/km → min/mi  (1 mile = 1.60934 km)
    pace = paceMinPerKm * 1.60934;
    unit = '/mi';
  }
  final min = pace.floor();
  final sec = ((pace - min) * 60).round().toString().padLeft(2, '0');
  return "$min'$sec\"$unit";
}

// ─── Date ─────────────────────────────────────────────────────────────────────

/// Formats a DateTime to "Mon, Mar 7  •  14:30"
String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final dayName = days[date.weekday - 1];
  final month = months[date.month - 1];
  final hour = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$dayName, $month ${date.day}  •  $hour:$min';
}

/// Formats a day streak into readable copy.
String formatStreak(int days) {
  if (days <= 0) return 'No streak';
  return '$days day${days == 1 ? '' : 's'}';
}

