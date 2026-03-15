import 'package:flutter/cupertino.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_map_widget.dart';

/// A self-contained styled card designed to be captured as a share image.
/// Wrap this in a [RepaintBoundary] with a [GlobalKey] to capture it.
///
/// Contains: app branding, route map, date, distance, duration, pace.
class ShareableCardWidget extends ConsumerWidget {
  final ActivityModel activity;

  const ShareableCardWidget({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetric = ref.watch(appSettingsProvider).useMetric;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Route Map ────────────────────────────────────────────
          RouteMapWidget(
            coordinates: activity.routeCoordinates,
            interactive: false,
            height: 200,
          ),

          // ── Stats ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                Text(
                  formatDate(activity.date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 12),

                // Distance — hero stat
                Text(
                  formatDistance(activity.distance, useMetric: useMetric),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),

                const SizedBox(height: 10),

                // Duration + Pace row
                Row(
                  children: [
                    _StatPill(
                      icon: CupertinoIcons.timer,
                      value: formatDuration(activity.durationSeconds),
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: CupertinoIcons.speedometer,
                      value: formatPace(activity.pace, useMetric: useMetric),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Branding footer
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.flame_fill,
                      color: CupertinoColors.systemOrange,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'RunTracker',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.systemOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatPill({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
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
            ),
          ),
        ],
      ),
    );
  }
}

