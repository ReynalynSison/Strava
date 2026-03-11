import 'package:flutter/cupertino.dart';
import '../models/activity_model.dart';
import '../services/share_service.dart';
import '../utils/formatters.dart';
import '../widgets/activity_stats_widget.dart';
import '../widgets/animated_route_widget.dart';
import '../widgets/route_map_widget.dart';
import '../widgets/shareable_card_widget.dart';

/// Full Activity Summary screen — shown after a run is saved.
class ActivitySummaryScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivitySummaryScreen({super.key, required this.activity});

  @override
  State<ActivitySummaryScreen> createState() => _ActivitySummaryScreenState();
}

class _ActivitySummaryScreenState extends State<ActivitySummaryScreen> {
  // Key attached to the RepaintBoundary wrapping ShareableCardWidget
  final GlobalKey _shareKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      await ShareService().shareActivityImage(
        _shareKey,
        text:
            'Just ran ${formatDistance(widget.activity.distance)} in ${formatDuration(widget.activity.durationSeconds)} 🏃 #RunTracker',
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
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Summary'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Date ────────────────────────────────────────────────
              Text(
                formatDate(widget.activity.date),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),

              const SizedBox(height: 20),

              // ── Stats Card ──────────────────────────────────────────
              ActivityStatsWidget(activity: widget.activity),

              const SizedBox(height: 16),

              // ── Route Map + animated draw-in ────────────────────────
              // Stack: static map tiles at bottom, animated route on top.
              // AnimatedRouteWidget uses pure-Canvas math so it works
              // immediately without waiting for the map camera to initialize.
              SizedBox(
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Static map — tiles only, no animation
                      RouteMapWidget(
                        coordinates: widget.activity.routeCoordinates,
                        interactive: false,
                        height: 280,
                        showEndMarkers: false,
                        animate: false,
                      ),
                      // Animated route drawn via CustomPaint (no MapController needed)
                      Positioned.fill(
                        child: AnimatedRouteWidget(
                          coordinates: widget.activity.routeCoordinates,
                          distance: widget.activity.distance,
                          durationSeconds: widget.activity.durationSeconds,
                          pace: widget.activity.pace,
                          animationDuration: const Duration(seconds: 3),
                          transparentBackground: true,
                          showStatsOverlay: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Shareable Card Preview ──────────────────────────────
              // Wrapped in RepaintBoundary — this is what gets captured
              const Text(
                'SHARE PREVIEW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: RepaintBoundary(
                  key: _shareKey,
                  child: ShareableCardWidget(activity: widget.activity),
                ),
              ),

              const SizedBox(height: 28),

              // ── Share Button ────────────────────────────────────────
              CupertinoButton(
                color: CupertinoColors.systemBlue,
                borderRadius: BorderRadius.circular(12),
                onPressed: _isSharing ? null : _share,
                child: _isSharing
                    ? const CupertinoActivityIndicator()
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.share,
                              color: CupertinoColors.white),
                          SizedBox(width: 8),
                          Text(
                            'Share',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 12),

              // ── Done Button ─────────────────────────────────────────
              CupertinoButton(
                borderRadius: BorderRadius.circular(12),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
