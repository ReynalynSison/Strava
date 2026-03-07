import 'package:flutter/cupertino.dart';
import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../screens/activity_summary_screen.dart';
import '../widgets/activity_card_widget.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onGoToRecord;

  const HistoryScreen({super.key, this.onGoToRecord});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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
      _activities = activities;
      _isLoading = false;
    });
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  void _confirmDelete(ActivityModel activity) {
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
              await _storage.deleteActivity(activity.id);
              if (!mounted) return;
              setState(() => _activities.remove(activity));
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
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('History'),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : _activities.isEmpty
              ? _buildEmptyState()
              : _buildList(),
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
              onPressed: widget.onGoToRecord,
              child: const Text('Record Your First Run'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── List ─────────────────────────────────────────────────────────────────

  Widget _buildList() {
    return CustomScrollView(
      slivers: [
        // Pull-to-refresh
        CupertinoSliverRefreshControl(
          onRefresh: _loadActivities,
        ),

        // Total count header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${_activities.length} ${_activities.length == 1 ? 'run' : 'runs'}',
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
              final activity = _activities[index];
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
                onDelete: () => _confirmDelete(activity),
              );
            },
            childCount: _activities.length,
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

