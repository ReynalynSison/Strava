import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';
import 'route_map_widget.dart';

/// A tappable activity card with a mini route map, stats row,
/// and swipe-left-to-delete using flutter_slidable.
class ActivityCardWidget extends ConsumerWidget {
  final ActivityModel activity;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ActivityCardWidget({
    super.key,
    required this.activity,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetric = ref.watch(appSettingsProvider).useMetric;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Slidable(
        key: ValueKey(activity.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: CupertinoColors.systemRed,
              foregroundColor: CupertinoColors.white,
              icon: CupertinoIcons.delete,
              label: 'Delete',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Mini Map (static) ──────────────────────────────
                RouteMapWidget(
                  coordinates: activity.routeCoordinates,
                  interactive: false,
                  height: 110,
                  animate: false,
                ),

                // ── Info Row ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      Text(
                        formatDate(activity.date),
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.label
                              .resolveFrom(context)
                              .withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Stats row
                      Row(
                        children: [
                          _Stat(
                            icon: CupertinoIcons.map_pin_ellipse,
                            value: formatDistance(activity.distance, useMetric: useMetric),
                          ),
                          const SizedBox(width: 20),
                          _Stat(
                            icon: CupertinoIcons.timer,
                            value: formatDuration(activity.durationSeconds),
                          ),
                          const SizedBox(width: 20),
                          _Stat(
                            icon: CupertinoIcons.speedometer,
                            value: formatPace(activity.pace, useMetric: useMetric),
                          ),
                          const Spacer(),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: CupertinoColors.tertiaryLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper ─────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: CupertinoColors.systemOrange),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

