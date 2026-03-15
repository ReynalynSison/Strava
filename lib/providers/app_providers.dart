import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart' as core;
import 'activity_provider.dart';
import 'app_settings_provider.dart';
import 'tracking_provider.dart';

export 'activity_provider.dart';
export 'app_settings_provider.dart';
export 'tracking_provider.dart';

/// Small selector provider used by UI/formatters to avoid repeating
/// `ref.watch(appSettingsProvider).useMetric` everywhere.
final useMetricProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider).useMetric;
});

/// Shared formatter facade bound to the current unit preference.
final appFormattersProvider = Provider<core.AppFormatters>((ref) {
  return core.AppFormatters(useMetric: ref.watch(useMetricProvider));
});


