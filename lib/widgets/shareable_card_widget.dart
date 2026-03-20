import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_map_widget.dart';
import 'route_outline_painter.dart';

enum ShareCardBackgroundMode { map, photo }

/// A self-contained styled card designed to be captured as a share image.
/// Wrap this in a [RepaintBoundary] with a [GlobalKey] to capture it.
class ShareableCardWidget extends ConsumerWidget {
  final ActivityModel activity;
  final ShareCardBackgroundMode backgroundMode;

  const ShareableCardWidget({
    super.key,
    required this.activity,
    this.backgroundMode = ShareCardBackgroundMode.map,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetric = ref.watch(appSettingsProvider).useMetric;
    if (backgroundMode == ShareCardBackgroundMode.photo) {
      return _buildStyledPhotoPreview(useMetric);
    }

    return _buildMapCardPreview(context, useMetric);
  }

  Widget _buildStyledPhotoPreview(bool useMetric) {
    return SizedBox(
      width: 360,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPhotoBackground(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Color(0xDD000000), Color(0x00000000)],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayStat(
                    'Distance',
                    formatDistance(activity.distance, useMetric: useMetric),
                  ),
                  const SizedBox(height: 16),
                  _OverlayStat(
                    'Pace',
                    formatPace(activity.pace, useMetric: useMetric),
                  ),
                  const SizedBox(height: 16),
                  _OverlayStat('Time', formatDuration(activity.durationSeconds)),
                  const SizedBox(height: 24),
                  if (activity.routeCoordinates.length >= 2)
                    RouteOutlineWidget(
                      coordinates: activity.routeCoordinates,
                      size: 120,
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'STRIVO',
                    style: TextStyle(
                      color: Color(0xFF2424EA),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(blurRadius: 6, color: CupertinoColors.black),
                      ],
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

  Widget _buildMapCardPreview(BuildContext context, bool useMetric) {
    final cardBg = CupertinoColors.systemBackground.resolveFrom(context);
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RouteMapWidget(
            coordinates: activity.routeCoordinates,
            interactive: false,
            height: 200,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(activity.date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  formatDistance(activity.distance, useMetric: useMetric),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatPill(
                      icon: CupertinoIcons.timer,
                      value: formatDuration(activity.durationSeconds),
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: CupertinoIcons.speedometer,
                      value: formatPace(activity.pace, useMetric: useMetric),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(
                      CupertinoIcons.flame_fill,
                      color: CupertinoColors.systemOrange,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'RunTracker',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.systemOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBackground() {
    final path = activity.photoPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }

    return RouteMapWidget(
      coordinates: activity.routeCoordinates,
      interactive: false,
      height: 640,
    );
  }
}

class _OverlayStat extends StatelessWidget {
  final String label;
  final String value;

  const _OverlayStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            shadows: <Shadow>[
              Shadow(blurRadius: 6, color: CupertinoColors.black),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            shadows: <Shadow>[
              Shadow(blurRadius: 8, color: CupertinoColors.black),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatPill({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: CupertinoColors.systemOrange),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

