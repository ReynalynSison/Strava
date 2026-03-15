import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';
import '../widgets/motivation_summary_widget.dart';
import '../widgets/profile_avatar_widget.dart';

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  Future<void> _refreshActivities(WidgetRef ref) async {
    await ref.read(activityProvider.notifier).loadActivities();
  }

  // ─── Computed Stats ───────────────────────────────────────────────────────

  /// Activities in the current calendar week (Mon–Sun).
  List<ActivityModel> _thisWeekActivities(List<ActivityModel> activities) {
    final now = DateTime.now();
    // Monday of the current week
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 7));
    return activities
        .where((a) => !a.date.isBefore(monday) && a.date.isBefore(sunday))
        .toList();
  }

  /// Activities in the current calendar month.
  List<ActivityModel> _thisMonthActivities(List<ActivityModel> activities) {
    final now = DateTime.now();
    return activities
        .where((a) => a.date.year == now.year && a.date.month == now.month)
        .toList();
  }

  double _totalDistanceKm(List<ActivityModel> list) =>
      list.fold(0.0, (sum, a) => sum + a.distance) / 1000;

  int _totalDurationSeconds(List<ActivityModel> list) =>
      list.fold(0, (sum, a) => sum + a.durationSeconds);

  double _avgPace(List<ActivityModel> list) {
    if (list.isEmpty) return 0;
    return list.fold(0.0, (sum, a) => sum + a.pace) / list.length;
  }

  /// Returns a list of 7 daily distance totals (km) for the current week,
  /// index 0 = Monday, index 6 = Sunday.
  List<double> _weeklyBarData(List<ActivityModel> thisWeekActivities) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final List<double> data = List.filled(7, 0.0);
    for (final a in thisWeekActivities) {
      final day = a.date
          .difference(monday)
          .inDays
          .clamp(0, 6);
      data[day] += a.distance / 1000;
    }
    return data;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final activityState = ref.watch(activityProvider);
    final motivationSummary = ref.watch(motivationSummaryProvider);
    final activities = activityState.activities;
    final thisWeekActivities = _thisWeekActivities(activities);
    final thisMonthActivities = _thisMonthActivities(activities);
    final username = settings.username.isEmpty ? 'Runner' : settings.username;
    final useMetric = settings.useMetric;
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final isDark = brightness == Brightness.dark;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('You'),
            alwaysShowMiddle: false,
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () => _refreshActivities(ref),
          ),
          if (activityState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator(radius: 16)),
            )
          else ...[
            // ── Profile Header ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildProfileHeader(username, isDark, activities.length),
            ),

            SliverToBoxAdapter(
              child: MotivationSummaryWidget(
                summary: motivationSummary,
                useMetric: useMetric,
              ),
            ),

            // ── This Week ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader('THIS WEEK'),
            ),
            SliverToBoxAdapter(
              child: _buildStatsRow(
                thisWeekActivities,
                context,
                isDark,
                useMetric,
              ),
            ),

            // ── Weekly bar chart ─────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildWeeklyChart(isDark, thisWeekActivities),
            ),

            // ── This Month ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader('THIS MONTH'),
            ),
            SliverToBoxAdapter(
              child: _buildStatsRow(
                thisMonthActivities,
                context,
                isDark,
                useMetric,
              ),
            ),

            // ── All Time ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader('ALL TIME'),
            ),
            SliverToBoxAdapter(
              child: _buildAllTimeCard(isDark, useMetric, activities),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildProfileHeader(String username, bool isDark, int runsCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? CupertinoColors.black.withValues(alpha: 0.3)
                  : CupertinoColors.systemGrey5,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Editable avatar ──────────────────────────────────
            const ProfileAvatarWidget(size: 64, editable: true),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$runsCount run${runsCount == 1 ? '' : 's'} recorded',
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap photo to change',
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      List<ActivityModel> list, BuildContext context, bool isDark, bool useMetric) {
    final distKm = _totalDistanceKm(list);
    final duration = _totalDurationSeconds(list);
    final pace = _avgPace(list);
    final runs = list.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatTile('Distance',
              formatDistance(distKm * 1000, useMetric: useMetric), CupertinoIcons.location_solid,
              const Color(0xFFFC4C02), isDark),
          const SizedBox(width: 10),
          _buildStatTile('Time',
              formatDuration(duration), CupertinoIcons.timer,
              CupertinoColors.activeBlue, isDark),
          const SizedBox(width: 10),
          _buildStatTile(
              'Runs',
              '$runs',
              CupertinoIcons.flame_fill,
              CupertinoColors.systemGreen,
              isDark),
          const SizedBox(width: 10),
          _buildStatTile(
              'Avg Pace',
              pace > 0 ? formatPace(pace, useMetric: useMetric) : '--',
              CupertinoIcons.speedometer,
              CupertinoColors.systemPurple,
              isDark),
        ],
      ),
    );
  }

  Widget _buildStatTile(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground,
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
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(bool isDark, List<ActivityModel> thisWeekActivities) {
    final data = _weeklyBarData(thisWeekActivities);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? CupertinoColors.black.withValues(alpha: 0.3)
                  : CupertinoColors.systemGrey5,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Distance (km)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final val = data[i];
                  final fraction =
                      maxVal > 0 ? (val / maxVal).clamp(0.0, 1.0) : 0.0;
                  final isToday = i == todayIndex;
                  final barColor = isToday
                      ? const Color(0xFFFC4C02)
                      : (isDark
                          ? CupertinoColors.systemGrey
                          : CupertinoColors.systemGrey4);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (val > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  val.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isToday
                                        ? const Color(0xFFFC4C02)
                                        : CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ),
                            ),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: fraction < 0.05 ? 0.05 : fraction,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            days[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isToday
                                  ? const Color(0xFFFC4C02)
                                  : CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTimeCard(
    bool isDark,
    bool useMetric,
    List<ActivityModel> activities,
  ) {
    final totalKm = _totalDistanceKm(activities);
    final totalSecs = _totalDurationSeconds(activities);
    final avgPace = _avgPace(activities);
    final runs = activities.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFC4C02), Color(0xFFFF8C42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildAllTimeStat(
                    formatDistance(totalKm * 1000, useMetric: useMetric), 'Total Distance'),
                _buildAllTimeStat('$runs', 'Total Runs'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAllTimeStat(formatDuration(totalSecs), 'Total Time'),
                _buildAllTimeStat(
                    avgPace > 0 ? formatPace(avgPace, useMetric: useMetric) : '--', 'Avg Pace'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTimeStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

