import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';


class ActivityStatsWidget extends ConsumerWidget {
  final ActivityModel activity;

  const ActivityStatsWidget({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetric = ref.watch(appSettingsProvider).useMetric;
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(
            icon: CupertinoIcons.map_pin_ellipse,
            value: formatDistance(activity.distance, useMetric: useMetric),
            label: 'Distance',
          ),
          _Divider(),
          _StatColumn(
            icon: CupertinoIcons.timer,
            value: formatDuration(activity.durationSeconds),
            label: 'Duration',
          ),
          _Divider(),
          _StatColumn(
            icon: CupertinoIcons.speedometer,
            value: formatPace(activity.pace, useMetric: useMetric),
            label: 'Pace',
          ),
        ],
      ),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: CupertinoColors.systemOrange),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.label
                .resolveFrom(context)
                .withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: CupertinoColors.separator);
  }
}

