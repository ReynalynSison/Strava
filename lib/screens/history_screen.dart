import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../services/demo_service.dart';
import '../screens/activity_summary_screen.dart';
import '../widgets/activity_card_widget.dart';

// --- Theme Constants (Blue Palette) ---
const Color iosBg = Color(0xFFF2F2F7);
const Color themeBlue = CupertinoColors.activeBlue;
const Color deepNavy = Color(0xFF001D39);

final _historySeedingProvider = StateProvider.autoDispose<bool>((ref) => false);

class HistoryScreen extends ConsumerWidget {
  final VoidCallback? onGoToRecord;

  const HistoryScreen({super.key, this.onGoToRecord});

  // ─── Demo Seeder Logic (Blue Theme Updated) ────────────────────────────────

  Future<void> _seedDemo(BuildContext context, WidgetRef ref) async {
    ref.read(_historySeedingProvider.notifier).state = true;
    try {
      await DemoService().seedDemoRun();
      if (!context.mounted) return;
      await ref.read(activityProvider.notifier).loadActivities();
    } finally {
      if (context.mounted) {
        ref.read(_historySeedingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _seedStationary(BuildContext context, WidgetRef ref) async {
    ref.read(_historySeedingProvider.notifier).state = true;
    try {
      await DemoService().seedStationaryDemo();
      if (!context.mounted) return;
      await ref.read(activityProvider.notifier).loadActivities();
    } finally {
      if (context.mounted) {
        ref.read(_historySeedingProvider.notifier).state = false;
      }
    }
  }

  void _showDemoSheet(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Design Tester'),
        message: const Text('Add demo activities to test your blue layout.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _seedDemo(context, ref);
            },
            child: const Text('🏃 Add 2.1 km Lisbon Run'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _seedStationary(context, ref);
            },
            child: const Text('📍 Add Stationary Point'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // ─── Delete Logic ──────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref, ActivityModel activity) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Activity?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(activityProvider.notifier).deleteActivity(activity.id);
            },
            child: const Text('Delete'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(activityProvider);
    final isSeeding = ref.watch(_historySeedingProvider);
    final activities = activityState.activities;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : iosBg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // --- Premium Sliver Navbar (Consistent with YouScreen) ---
          CupertinoSliverNavigationBar(
            largeTitle: const Text('History', style: TextStyle(letterSpacing: -0.5)),
            backgroundColor: (isDark ? CupertinoColors.black : iosBg).withOpacity(0.8),
            border: null,
            trailing: isSeeding
                ? const CupertinoActivityIndicator()
                : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showDemoSheet(context, ref),
              child: const Icon(CupertinoIcons.sparkles, size: 22, color: themeBlue),
            ),
          ),

          CupertinoSliverRefreshControl(
            onRefresh: () => ref.read(activityProvider.notifier).loadActivities(),
          ),

          if (activityState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            )
          else if (activities.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(isDark),
            )
          else
            _buildList(context, ref, activities, isDark),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: themeBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.graph_square_fill,
                size: 60,
                color: themeBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No activities yet',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? CupertinoColors.white : deepNavy
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your fitness journey starts here. Record a run and see your history grow.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel,
                  height: 1.4
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton(
              color: themeBlue,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              onPressed: onGoToRecord,
              child: const Text('Start First Activity', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── List Section ─────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context, WidgetRef ref, List<ActivityModel> activities, bool isDark) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ALL ACTIVITIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                Text(
                  '${activities.length} total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeBlue,
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final activity = activities[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ActivityCardWidget(
                    activity: activity,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => ActivitySummaryScreen(activity: activity),
                        ),
                      );
                    },
                    onDelete: () => _confirmDelete(context, ref, activity),
                  ),
                );
              },
              childCount: activities.length,
            ),
          ),
        ),
      ],
    );
  }
}