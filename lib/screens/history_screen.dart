import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../services/demo_service.dart';
import '../screens/activity_summary_screen.dart';
import '../widgets/activity_card_widget.dart';

final _historySeedingProvider = StateProvider.autoDispose<bool>((ref) => false);

class HistoryScreen extends ConsumerWidget {
  final VoidCallback? onGoToRecord;

  const HistoryScreen({super.key, this.onGoToRecord});

  // ─── Demo Seeder ──────────────────────────────────────────────────────────

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
        title: const Text('Add Demo Run'),
        message: const Text(
            'Inserts a fake activity so you can test the UI without running.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _seedDemo(context, ref);
            },
            child: const Text('🏃 Demo Run (~2.1 km Lisbon loop)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _seedStationary(context, ref);
            },
            child: const Text('📍 Stationary Demo (0 m — single dot test)'),
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

  // ─── Delete ───────────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref, ActivityModel activity) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Run?'),
        content: const Text('This run will be permanently deleted.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(activityProvider.notifier).deleteActivity(activity.id);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('History'),
        trailing: isSeeding
            ? const CupertinoActivityIndicator()
            : GestureDetector(
                onTap: () => _showDemoSheet(context, ref),
                child: const Icon(
                  CupertinoIcons.wand_stars,
                  size: 22,
                  color: Color(0xFFFC4C02),
                ),
              ),
      ),
      child: activityState.isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : activities.isEmpty
              ? _buildEmptyState()
              : _buildList(context, ref, activities),
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
              CupertinoIcons.sportscourt,
              size: 72,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 20),
            const Text(
              'No runs yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your completed runs will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 28),
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(12),
              onPressed: onGoToRecord,
              child: const Text('Record Your First Run'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── List ─────────────────────────────────────────────────────────────────

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ActivityModel> activities,
  ) {
    return CustomScrollView(
      slivers: [
        // Pull-to-refresh
        CupertinoSliverRefreshControl(
          onRefresh: () => ref.read(activityProvider.notifier).loadActivities(),
        ),

        // Total count header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${activities.length} ${activities.length == 1 ? 'run' : 'runs'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ),

        // Activity cards
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final activity = activities[index];
              return ActivityCardWidget(
                activity: activity,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) =>
                          ActivitySummaryScreen(activity: activity),
                    ),
                  );
                },
                onDelete: () => _confirmDelete(context, ref, activity),
              );
            },
            childCount: activities.length,
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

