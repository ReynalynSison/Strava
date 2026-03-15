import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';
import '../widgets/motivation_summary_widget.dart';
import '../widgets/profile_avatar_widget.dart';
import '../widgets/route_map_widget.dart';
import '../widgets/route_outline_painter.dart';
import 'activity_summary_screen.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onGoToRecord;

  const HomeScreen({super.key, this.onGoToRecord});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final activityState = ref.watch(activityProvider);
    final motivationSummary = ref.watch(motivationSummaryProvider);
    final feedActivities =
        activityState.activities.where((a) => a.postedToFeed).toList();
    final username = settings.username.isEmpty ? 'Runner' : settings.username;
    final useMetric = settings.useMetric;
    Future<void> refreshFeed() async {
      await ref.read(activityProvider.notifier).loadActivities();
    }

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Feed'),
            alwaysShowMiddle: false,
          ),
          CupertinoSliverRefreshControl(onRefresh: refreshFeed),

          if (activityState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator(radius: 16)),
            )
          else ...[
            if (activityState.activities.isNotEmpty)
              SliverToBoxAdapter(
                child: MotivationSummaryWidget(
                  summary: motivationSummary,
                  useMetric: useMetric,
                ),
              ),
            if (feedActivities.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(onGoToRecord: onGoToRecord),
              )
            else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _FeedPostCard(
                      activity: feedActivities[index],
                      username: username,
                      useMetric: useMetric,
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => ActivitySummaryScreen(
                              activity: feedActivities[index]),
                        ),
                      ),
                    ),
                childCount: feedActivities.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({required VoidCallback? onGoToRecord}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.person_2_fill,
              size: 72,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Your feed is empty',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'When you finish a run, choose to post it here and add a caption.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: CupertinoColors.secondaryLabel),
            ),
            const SizedBox(height: 28),
            CupertinoButton(
              color: const Color(0xFFFC4C02),
              borderRadius: BorderRadius.circular(14),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              onPressed: onGoToRecord,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.play_fill,
                      color: CupertinoColors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Record a Run',
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

// ── Feed Post Card ─────────────────────────────────────────────────────────────

class _FeedPostCard extends StatelessWidget {
  final ActivityModel activity;
  final String username;
  final bool useMetric;
  final VoidCallback onTap;

  const _FeedPostCard({
    required this.activity,
    required this.username,
    required this.useMetric,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? CupertinoColors.black.withValues(alpha: 0.25)
                    : CupertinoColors.systemGrey5,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: avatar + name + date ──────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    // Avatar
                    const ProfileAvatarWidget(size: 42, editable: false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formatDate(activity.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Activity type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFC4C02).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🏃 Run',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFC4C02),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Caption ───────────────────────────────────────────
              if (activity.caption != null &&
                  activity.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(
                    activity.caption!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

              // ── Photo or Route Map ────────────────────────────────
              _buildMediaSection(activity),

              // ── Stats Row ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                      icon: CupertinoIcons.location_solid,
                      label: 'Distance',
                      value: formatDistance(activity.distance, useMetric: useMetric),
                      color: const Color(0xFFFC4C02),
                    ),
                    _StatChip(
                      icon: CupertinoIcons.timer,
                      label: 'Time',
                      value: formatDuration(activity.durationSeconds),
                      color: CupertinoColors.activeBlue,
                    ),
                    _StatChip(
                      icon: CupertinoIcons.speedometer,
                      label: 'Pace',
                      value: formatPace(activity.pace, useMetric: useMetric),
                      color: CupertinoColors.systemPurple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Media section: photo with overlay or route map fallback ───────────────
  Widget _buildMediaSection(ActivityModel activity) {
    final path = activity.photoPath;
    if (path != null && File(path).existsSync()) {
      return SizedBox(
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            Image.file(File(path), fit: BoxFit.cover),

            // Top fade — non-interactive
            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),

            // Bottom fade — non-interactive
            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),

            // Responsive overlay — scales route art + gaps to available height
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _OverlayStat('Distance', formatDistance(activity.distance, useMetric: useMetric)),
                        const SizedBox(height: 6),
                        _OverlayStat('Pace', formatPace(activity.pace, useMetric: useMetric)),
                        const SizedBox(height: 6),
                        _OverlayStat('Time', formatDuration(activity.durationSeconds)),
                        const SizedBox(height: 8),
                        if (activity.routeCoordinates.isNotEmpty)
                          RouteOutlineWidget(
                            coordinates: activity.routeCoordinates,
                            size: 80,
                          ),
                        const SizedBox(height: 6),
                        const Text(
                          'STRAVA',
                          style: TextStyle(
                            color: Color(0xFFFC4C02),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(blurRadius: 4, color: CupertinoColors.black)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RouteMapWidget(
      coordinates: activity.routeCoordinates,
      interactive: false,
      height: 180,
    );
  }
}

// ── _OverlayStat ──────────────────────────────────────────────────────────────

class _OverlayStat extends StatelessWidget {
  final String label;
  final String value;
  const _OverlayStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              shadows: [Shadow(blurRadius: 4, color: CupertinoColors.black)],
            )),
        Text(value,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(blurRadius: 6, color: CupertinoColors.black)],
            )),
      ],
    );
  }
}

// ── _StatChip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: CupertinoColors.secondaryLabel)),
      ],
    );
  }
}
