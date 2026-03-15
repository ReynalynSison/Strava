import 'package:flutter/cupertino.dart';

import '../providers/activity_provider.dart';
import '../utils/formatters.dart';

class MotivationSummaryWidget extends StatelessWidget {
  final MotivationSummary summary;
  final bool useMetric;
  final String title;

  const MotivationSummaryWidget({
    super.key,
    required this.summary,
    required this.useMetric,
    this.title = 'MOTIVATION',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MotivationCard(
                  icon: CupertinoIcons.flag_fill,
                  color: const Color(0xFFFC4C02),
                  label: 'PB Distance',
                  value: summary.longestRun != null
                      ? formatDistance(summary.longestRun!.distance,
                          useMetric: useMetric)
                      : 'No PB yet',
                  subtitle: summary.longestRun != null
                      ? 'Longest run'
                      : 'Finish a run to unlock',
                  isDark: isDark,
                  cardColor: cardColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MotivationCard(
                  icon: CupertinoIcons.speedometer,
                  color: CupertinoColors.systemPurple,
                  label: 'Best Pace',
                  value: summary.bestPaceRun != null
                      ? formatPace(summary.bestPaceRun!.pace,
                          useMetric: useMetric)
                      : '--',
                  subtitle: summary.bestPaceRun != null
                      ? 'Fastest 1 km+ run'
                      : 'Needs a valid 1 km+ run',
                  isDark: isDark,
                  cardColor: cardColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MotivationCard(
                  icon: CupertinoIcons.flame_fill,
                  color: CupertinoColors.systemGreen,
                  label: 'Current Streak',
                  value: formatStreak(summary.currentStreakDays),
                  subtitle: summary.currentStreakDays > 0
                      ? 'Consecutive active days'
                      : 'Run today to start one',
                  isDark: isDark,
                  cardColor: cardColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MotivationCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String subtitle;
  final bool isDark;
  final Color cardColor;

  const _MotivationCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.isDark,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? CupertinoColors.black.withValues(alpha: 0.3)
                : CupertinoColors.systemGrey5,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

