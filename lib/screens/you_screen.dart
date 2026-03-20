import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  // ─── Computed Stats (Logic remains untouched) ──────────────────────────
  List<ActivityModel> _thisWeekActivities(List<ActivityModel> activities) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 7));
    return activities
        .where((a) => !a.date.isBefore(monday) && a.date.isBefore(sunday))
        .toList();
  }

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

  List<double> _weeklyBarData(List<ActivityModel> thisWeekActivities) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final List<double> data = List.filled(7, 0.0);
    for (final a in thisWeekActivities) {
      final day = a.date.difference(monday).inDays.clamp(0, 6);
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
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final scaffoldBg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final navBg = CupertinoColors.systemBackground.resolveFrom(context);

    // --- BLUE THEME COLOR ---
    const Color themeBlue = CupertinoColors.activeBlue;

    return CupertinoPageScaffold(
      backgroundColor: scaffoldBg,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('You'),
            border: null,
            backgroundColor: navBg.withValues(alpha: 0.85),
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
              child: _buildProfileHeader(username, isDark, activities.length, themeBlue),
            ),

            SliverToBoxAdapter(
              child: MotivationSummaryWidget(
                summary: motivationSummary,
                useMetric: useMetric,
              ),
            ),

            // ── This Week ────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildSectionHeader('THIS WEEK')),
            SliverToBoxAdapter(
              child: _buildStatsRow(thisWeekActivities, context, isDark, useMetric, themeBlue),
            ),
            SliverToBoxAdapter(
              child: _buildWeeklyChart(context, isDark, thisWeekActivities, themeBlue),
            ),

            // ── This Month ───────────────────────────────────────────
            SliverToBoxAdapter(child: _buildSectionHeader('THIS MONTH')),
            SliverToBoxAdapter(
              child: _buildStatsRow(thisMonthActivities, context, isDark, useMetric, themeBlue),
            ),

            // ── All Time ─────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildSectionHeader('ALL TIME PROGRESS')),
            SliverToBoxAdapter(
              child: _buildAllTimeCard(useMetric, activities, themeBlue),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ],
      ),
    );
  }

  // ─── Widgets with Blue Theme ──────────────────────────────────────────────

  Widget _buildProfileHeader(String username, bool isDark, int runsCount, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const ProfileAvatarWidget(size: 72, editable: true),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$runsCount ${runsCount == 1 ? 'RUN' : 'RUNS'} COMPLETED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: themeColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: CupertinoColors.secondaryLabel,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<ActivityModel> list, BuildContext context, bool isDark, bool useMetric, Color themeColor) {
    final distKm = _totalDistanceKm(list);
    final duration = _totalDurationSeconds(list);
    final pace = _avgPace(list);
    final runs = list.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.1,
        children: [
          _buildStatTile(context, 'Distance', formatDistance(distKm * 1000, useMetric: useMetric),
              CupertinoIcons.map_fill, themeColor, isDark),
          _buildStatTile(context, 'Duration', formatDuration(duration),
              CupertinoIcons.stopwatch_fill, const Color(0xFF5856D6), isDark), // Indigo for duration
          _buildStatTile(context, 'Runs', '$runs',
              CupertinoIcons.flame_fill, CupertinoColors.systemTeal, isDark),
          _buildStatTile(context, 'Avg Pace', pace > 0 ? formatPace(pace, useMetric: useMetric) : '--',
              CupertinoIcons.gauge, CupertinoColors.systemPurple, isDark),
        ],
      ),
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                Text(label, style: const TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, bool isDark, List<ActivityModel> thisWeekActivities, Color themeColor) {
    final data = _weeklyBarData(thisWeekActivities);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WEEKLY ACTIVITY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CupertinoColors.secondaryLabel)),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final val = data[i];
                  final fraction = maxVal > 0 ? (val / maxVal).clamp(0.08, 1.0) : 0.08;
                  final isToday = i == todayIndex;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (val > 0)
                          Text(val.toStringAsFixed(1),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                  color: isToday ? themeColor : CupertinoColors.secondaryLabel)),
                        const SizedBox(height: 4),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: fraction,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                gradient: isToday ? LinearGradient(
                                  colors: [themeColor, themeColor.withValues(alpha: 0.6)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ) : null,
                                color: isToday ? null : CupertinoColors.systemGrey5.resolveFrom(context),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(days[i],
                            style: TextStyle(fontSize: 11, fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                color: isToday ? themeColor : CupertinoColors.secondaryLabel)),
                      ],
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

  Widget _buildAllTimeCard(bool useMetric, List<ActivityModel> activities, Color themeColor) {
    final totalKm = _totalDistanceKm(activities);
    final totalSecs = _totalDurationSeconds(activities);
    final avgPace = _avgPace(activities);
    final runs = activities.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?q=80&w=2000&auto=format&fit=crop'), // Mas fitness-focused na nature image
            fit: BoxFit.cover,
            opacity: 0.25,
          ),
          gradient: LinearGradient(
            colors: [themeColor.withValues(alpha: 0.85), const Color(0xFF001D39)], // Navy-Blue gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAllTimeStat(formatDistance(totalKm * 1000, useMetric: useMetric), 'TOTAL DISTANCE'),
                _buildAllTimeStat('$runs', 'TOTAL RUNS'),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: CupertinoColors.white, thickness: 0.2),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAllTimeStat(formatDuration(totalSecs), 'TOTAL TIME'),
                _buildAllTimeStat(avgPace > 0 ? formatPace(avgPace, useMetric: useMetric) : '--', 'AVG PACE'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTimeStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: CupertinoColors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CupertinoColors.white.withValues(alpha: 0.7), letterSpacing: 0.5)),
      ],
    );
  }
}