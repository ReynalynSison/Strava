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

// --- Custom Palette ---
const Color stravaOrange = Color(0xFF4F4FFF);
const Color activityBlue = CupertinoColors.activeBlue;

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
    final navBg = CupertinoColors.systemBackground.resolveFrom(context);

    Future<void> refreshFeed() async {
      await ref.read(activityProvider.notifier).loadActivities();
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Activity Feed', style: TextStyle(letterSpacing: -0.5)),
            alwaysShowMiddle: false,
            border: null,
            backgroundColor: navBg.withValues(alpha: 0.9),
          ),
          CupertinoSliverRefreshControl(onRefresh: refreshFeed),

          if (activityState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator(radius: 16)),
            )
          else ...[
            if (activityState.activities.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: MotivationSummaryWidget(
                    summary: motivationSummary,
                    useMetric: useMetric,
                  ),
                ),
              ),
            if (feedActivities.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(
                  context,
                  onGoToRecord: onGoToRecord,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _FeedPostCard(
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
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required VoidCallback? onGoToRecord,
  }) {
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final descriptionColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: stravaOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons. person_2_fill,
                size: 80,
                color: stravaOrange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your feed is empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When you finish a run, choose to post it here and add a caption.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: descriptionColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton(
              color: stravaOrange,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              onPressed: onGoToRecord,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.play_circle_fill,
                    size: 20,
                    color: CupertinoColors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Record a Run',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: CupertinoColors.white,
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
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final subtleTextColor =
        CupertinoColors.label.resolveFrom(context).withValues(alpha: 0.72);
    final cardColor = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: CupertinoColors.black
                    .withValues(alpha: isDark ? 0.32 : 0.07),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ProfileAvatarWidget(size: 48, editable: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          formatDate(activity.date),
                          style: TextStyle(fontSize: 12, color: subtleTextColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: stravaOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '🏃 RUN',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: stravaOrange, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // ── Caption ───────────────────────────────────────────
            if (activity.caption != null && activity.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  activity.caption!,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),

            // ── Photo or Route Map ────────────────────────────────
            _buildMediaSection(activity),

            // ── Stats Row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      icon: CupertinoIcons.location_solid,
                      label: 'DISTANCE',
                      value: formatDistance(activity.distance, useMetric: useMetric),
                      color: stravaOrange,
                    ),
                  ),
                  Expanded(
                    child: _StatChip(
                      icon: CupertinoIcons.timer,
                      label: 'TIME',
                      value: formatDuration(activity.durationSeconds),
                      color: activityBlue,
                    ),
                  ),
                  Expanded(
                    child: _StatChip(
                      icon: CupertinoIcons.speedometer,
                      label: 'PACE',
                      value: formatPace(activity.pace, useMetric: useMetric),
                      color: CupertinoColors.systemPurple,
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

  Widget _buildMediaSection(ActivityModel activity) {
    final path = activity.photoPath;
    if (path != null && File(path).existsSync()) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(path), fit: BoxFit.cover),
              // High-quality Fade Overlays
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x77000000), Color(0x00000000), Color(0xAA000000)],
                  ),
                ),
              ),

              // ── Center Stats Overlay ──
              IgnorePointer(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _OverlayStat('DISTANCE', formatDistance(activity.distance, useMetric: useMetric)),
                        const SizedBox(height: 8),
                        _OverlayStat('PACE', formatPace(activity.pace, useMetric: useMetric)),
                        const SizedBox(height: 8),
                        _OverlayStat('TIME', formatDuration(activity.durationSeconds)),
                        const SizedBox(height: 16),
                        if (activity.routeCoordinates.isNotEmpty)
                          RouteOutlineWidget(
                            coordinates: activity.routeCoordinates,
                            size: 80,
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'STRIVO',
                          style: TextStyle(
                            color: stravaOrange,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 5,
                            shadows: [Shadow(blurRadius: 4, color: CupertinoColors.black)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Upload Date/Time (Lower Right) ──
              Positioned(
                bottom: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatUploadDate(activity.date),
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        shadows: [Shadow(blurRadius: 2, color: CupertinoColors.black)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatUploadTime(activity.date),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.white,
                        shadows: [Shadow(blurRadius: 2, color: CupertinoColors.black)],
                      ).copyWith(
                        color: CupertinoColors.white.withValues(alpha: 0.88),
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
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RouteMapWidget(
          coordinates: activity.routeCoordinates,
          interactive: false,
          height: 180,
        ),
      ),
    );
  }

  /// Formats the upload date as "Mar 19, 2026"
  String _formatUploadDate(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Formats the upload time as "2:45 PM"
  String _formatUploadTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              shadows: [Shadow(blurRadius: 4, color: CupertinoColors.black)],
            )),
        Text(value,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 10, color: CupertinoColors.black)],
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: CupertinoColors.secondaryLabel, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ],
    );
  }
}