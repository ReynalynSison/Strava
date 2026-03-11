import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import '../widgets/profile_avatar_widget.dart';

class YouScreen extends StatefulWidget {
  const YouScreen({super.key});

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen> {
  final StorageService _storage = StorageService();

  List<ActivityModel> _activities = [];
  bool _isLoading = true;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final activities = await _storage.loadAllActivities();
    if (!mounted) return;
    setState(() {
      _activities = activities;
      _isLoading = false;
    });
  }

  // ─── Computed Stats ───────────────────────────────────────────────────────

  /// Activities in the current calendar week (Mon–Sun).
  List<ActivityModel> get _thisWeekActivities {
    final now = DateTime.now();
    // Monday of the current week
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 7));
    return _activities
        .where((a) => !a.date.isBefore(monday) && a.date.isBefore(sunday))
        .toList();
  }

  /// Activities in the current calendar month.
  List<ActivityModel> get _thisMonthActivities {
    final now = DateTime.now();
    return _activities
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
  List<double> get _weeklyBarData {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final List<double> data = List.filled(7, 0.0);
    for (final a in _thisWeekActivities) {
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
  Widget build(BuildContext context) {
    final username =
        Hive.box("database").get("username", defaultValue: 'Runner') as String;
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final isDark = brightness == Brightness.dark;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('You'),
            alwaysShowMiddle: false,
          ),
          CupertinoSliverRefreshControl(onRefresh: _loadActivities),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator(radius: 16)),
            )
          else ...[
            // ── Profile Header ────────────────────────────────────────
            SliverToBoxAdapter(child: _buildProfileHeader(username, isDark)),

            // ── This Week ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader('THIS WEEK'),
            ),
            SliverToBoxAdapter(
              child: _buildStatsRow(
                _thisWeekActivities,
                context,
                isDark,
              ),
            ),

            // ── Weekly bar chart ─────────────────────────────────────
            SliverToBoxAdapter(child: _buildWeeklyChart(isDark)),

            // ── This Month ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader('THIS MONTH'),
            ),
            SliverToBoxAdapter(
              child: _buildStatsRow(
                _thisMonthActivities,
                context,
                isDark,
              ),
            ),

            // ── All Time ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader('ALL TIME'),
            ),
            SliverToBoxAdapter(
              child: _buildAllTimeCard(isDark),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildProfileHeader(String username, bool isDark) {
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
                    '${_activities.length} run${_activities.length == 1 ? '' : 's'} recorded',
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
      List<ActivityModel> list, BuildContext context, bool isDark) {
    final distKm = _totalDistanceKm(list);
    final duration = _totalDurationSeconds(list);
    final pace = _avgPace(list);
    final runs = list.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatTile('Distance',
              '${distKm.toStringAsFixed(2)} km', CupertinoIcons.location_solid,
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
              pace > 0 ? formatPace(pace) : '--',
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

  Widget _buildWeeklyChart(bool isDark) {
    final data = _weeklyBarData;
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

  Widget _buildAllTimeCard(bool isDark) {
    final totalKm = _totalDistanceKm(_activities);
    final totalSecs = _totalDurationSeconds(_activities);
    final avgPace = _avgPace(_activities);
    final runs = _activities.length;

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
                    '${totalKm.toStringAsFixed(1)} km', 'Total Distance'),
                _buildAllTimeStat('$runs', 'Total Runs'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAllTimeStat(formatDuration(totalSecs), 'Total Time'),
                _buildAllTimeStat(
                    avgPace > 0 ? formatPace(avgPace) : '--', 'Avg Pace'),
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

