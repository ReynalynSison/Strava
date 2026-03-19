import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../services/share_service.dart';
import '../utils/formatters.dart';
import '../widgets/activity_stats_widget.dart';
import '../widgets/route_map_widget.dart';
import '../widgets/shareable_card_widget.dart';

// --- Theme Constants (Blue Theme) ---
const Color themeBlue = CupertinoColors.activeBlue;
const Color themeTeal = Color(0xFF64FFDA);

final _summarySharingProvider =
StateProvider.autoDispose.family<bool, String>((ref, _) => false);

class ActivitySummaryScreen extends ConsumerStatefulWidget {
  final ActivityModel activity;

  const ActivitySummaryScreen({super.key, required this.activity});

  @override
  ConsumerState<ActivitySummaryScreen> createState() => _ActivitySummaryScreenState();
}

class _ActivitySummaryScreenState extends ConsumerState<ActivitySummaryScreen> {
  final GlobalKey _shareKey = GlobalKey();

  Future<void> _share() async {
    final useMetric = ref.read(appSettingsProvider).useMetric;
    final sharingState = ref.read(
      _summarySharingProvider(widget.activity.id).notifier,
    );
    sharingState.state = true;
    try {
      await ShareService().shareActivityImage(
        _shareKey,
        text:
        'Just ran ${formatDistance(widget.activity.distance, useMetric: useMetric)} in ${formatDuration(widget.activity.durationSeconds)} 🏃 #RunTracker',
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Share Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        sharingState.state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSharing = ref.watch(_summarySharingProvider(widget.activity.id));
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground.withOpacity(0.8),
        border: null,
        middle: const Text('Run Summary', style: TextStyle(fontWeight: FontWeight.w800)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeBlue)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Modern Header ──
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: themeBlue.withOpacity(0.2), width: 2),
                      ),
                      child: const Icon(CupertinoIcons.checkmark_seal_fill, color: themeBlue, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Activities Completed!',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatDate(widget.activity.date).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.secondaryLabel,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Stats Widget (With Blue Highlight) ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: themeBlue.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ActivityStatsWidget(activity: widget.activity),
                ),
              ),

              const SizedBox(height: 24),

              // ── Route Map ──
              _buildSectionLabel('LIVE ROUTE'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: CupertinoColors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: RouteMapWidget(
                    coordinates: widget.activity.routeCoordinates,
                    interactive: true,
                    height: 260,
                    animate: true,
                    showEndMarkers: true,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Share Preview ──
              _buildSectionLabel('SOCIAL PREVIEW'),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(isDark ? 0.35 : 0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: RepaintBoundary(
                    key: _shareKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ShareableCardWidget(activity: widget.activity),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Share Button ──
              CupertinoButton(
                color: themeBlue,
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.symmetric(vertical: 18),
                onPressed: isSharing ? null : _share,
                child: isSharing
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.share_up, color: CupertinoColors.white, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Share to Socials',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: CupertinoColors.secondaryLabel,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}