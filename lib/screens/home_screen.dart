import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import '../widgets/activity_card_widget.dart';
import 'activity_summary_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToRecord;

  const HomeScreen({super.key, this.onGoToRecord});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();

  List<ActivityModel> _activities = [];
  bool _isLoading = true;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  // ─── Data ─────────────────────────────────────────────────────────────────

  Future<void> _loadActivities() async {
    final activities = await _storage.loadAllActivities();
    if (!mounted) return;
    setState(() {
      _activities = activities; // already sorted newest first
      _isLoading = false;
    });
  }

  // ─── Computed Stats ───────────────────────────────────────────────────────

  double get _totalDistanceKm =>
      _activities.fold(0.0, (sum, a) => sum + a.distance) / 1000;

  int get _totalDurationSeconds =>
      _activities.fold(0, (sum, a) => sum + a.durationSeconds);

  ActivityModel? get _latestActivity =>
      _activities.isNotEmpty ? _activities.first : null;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final username =
        Hive.box("database").get("username", defaultValue: 'Runner') as String;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          // ── Large Nav Bar ──────────────────────────────────────────
          CupertinoSliverNavigationBar(
            largeTitle: Text('Hi, $username 👋'),
            alwaysShowMiddle: false,
          ),

          // Pull-to-refresh
          CupertinoSliverRefreshControl(
            onRefresh: _loadActivities,
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator(radius: 16)),
            )
          else if (_activities.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else ...[
            // ── Aggregate Stats Card ─────────────────────────────
            SliverToBoxAdapter(child: _buildStatsCard()),

            // ── Latest Run Header ────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: Text(
                  'LATEST RUN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // ── Latest Activity Card ─────────────────────────────
            if (_latestActivity != null)
              SliverToBoxAdapter(
                child: ActivityCardWidget(
                  activity: _latestActivity!,
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => ActivitySummaryScreen(
                          activity: _latestActivity!),
                    ),
                  ),
                  onDelete: () {}, // delete from History, not here
                ),
              ),

            // ── All Runs Header ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ALL RUNS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.secondaryLabel,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${_activities.length} total',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── All Activity Cards ───────────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final activity = _activities[index];
                  return ActivityCardWidget(
                    activity: activity,
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) =>
                            ActivitySummaryScreen(activity: activity),
                      ),
                    ),
                    onDelete: () {}, // delete managed from History tab
                  );
                },
                childCount: _activities.length,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ],
      ),
    );
  }

  // ─── Aggregate Stats Card ─────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemOrange,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _AggregateStat(
              label: 'Total Runs',
              value: '${_activities.length}',
              icon: CupertinoIcons.flag_fill,
            ),
            _VerticalDivider(),
            _AggregateStat(
              label: 'Total Distance',
              value: formatDistance(_totalDistanceKm * 1000),
              icon: CupertinoIcons.map_pin_ellipse,
            ),
            _VerticalDivider(),
            _AggregateStat(
              label: 'Total Time',
              value: formatDuration(_totalDurationSeconds),
              icon: CupertinoIcons.timer,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.flame,
              size: 72,
              color: CupertinoColors.systemOrange,
            ),
            const SizedBox(height: 20),
            const Text(
              'Ready to run?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Record your first run and your stats will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 28),
            CupertinoButton(
              color: CupertinoColors.systemOrange,
              borderRadius: BorderRadius.circular(14),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              onPressed: widget.onGoToRecord,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.play_fill,
                      color: CupertinoColors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Start First Run',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _AggregateStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AggregateStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: CupertinoColors.white, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: CupertinoColors.white.withValues(alpha: 0.3),
    );
  }
}
