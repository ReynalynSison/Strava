import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';
import '../widgets/route_outline_painter.dart';

/// Full-screen screen shown right after finishing a run.
/// The user can take/choose a photo; the run stats are overlaid on top.
/// Returns the chosen [File] photo (or null if skipped) to the caller.
class RunPhotoScreen extends ConsumerStatefulWidget {
  final ActivityModel activity;

  const RunPhotoScreen({super.key, required this.activity});

  @override
  ConsumerState<RunPhotoScreen> createState() => _RunPhotoScreenState();
}

class _RunPhotoScreenState extends ConsumerState<RunPhotoScreen> {
  File? _photo;
  final _picker = ImagePicker();
  final GlobalKey _captureKey = GlobalKey();

  // ─── Pick / Take ──────────────────────────────────────────────────────────

  Future<void> _openCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked != null && mounted) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _openGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null && mounted) {
      setState(() => _photo = File(picked.path));
    }
  }

  void _retake() => setState(() => _photo = null);

  void _skip() => Navigator.of(context).pop(null);

  void _usePhoto() => Navigator.of(context).pop(_photo);

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: _photo == null ? _buildPickerState() : _buildPreviewState(),
    );
  }

  // ─── No photo yet: choose how to add one ─────────────────────────────────

  Widget _buildPickerState() {
    final a = widget.activity;
    final useMetric = ref.watch(appSettingsProvider).useMetric;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark background
        Container(color: CupertinoColors.black),

        // Stats centred on screen
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Stats first (like reference image) ──────────────
              _StatLine('Distance', formatDistance(a.distance, useMetric: useMetric)),
              const SizedBox(height: 8),
              _StatLine('Pace', formatPace(a.pace, useMetric: useMetric)),
              const SizedBox(height: 8),
              _StatLine('Time', formatDuration(a.durationSeconds)),
              const SizedBox(height: 28),
              // ── Orange route shape (below stats, above branding) ─
              if (a.routeCoordinates.length >= 2)
                RouteOutlineWidget(
                  coordinates: a.routeCoordinates,
                  size: 160,
                ),
              const SizedBox(height: 12),
              // ── App branding ─────────────────────────────────────
              const Text(
                'STRAVA',
                style: TextStyle(
                  color: Color(0xFFFC4C02),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Add a photo to your run',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),

        // Bottom buttons
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Column(
            children: [
              CupertinoButton(
                color: const Color(0xFFFC4C02),
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 16),
                onPressed: _openCamera,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.camera_fill,
                        color: CupertinoColors.white),
                    SizedBox(width: 10),
                    Text(
                      'Take a Photo',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 16),
                onPressed: _openGallery,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.photo,
                        color: CupertinoColors.label),
                    SizedBox(width: 10),
                    Text(
                      'Choose from Library',
                      style: TextStyle(
                        color: CupertinoColors.label,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: _skip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Photo taken: show stats overlay ─────────────────────────────────────

  Widget _buildPreviewState() {
    final a = widget.activity;
    final useMetric = ref.watch(appSettingsProvider).useMetric;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Full-screen photo ───────────────────────────────────────
        RepaintBoundary(
          key: _captureKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                _photo!,
                fit: BoxFit.cover,
              ),

              // Dark scrim at top so text is readable
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Color(0xCC000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),

              // Dark scrim at bottom
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [
                      Color(0xDD000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),

              // ── Stats overlay (centred) — matches reference image ─
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stats: small label + big value (like reference)
                    _OverlayStat('Distance', formatDistance(a.distance, useMetric: useMetric)),
                    const SizedBox(height: 20),
                    _OverlayStat('Pace', formatPace(a.pace, useMetric: useMetric)),
                    const SizedBox(height: 20),
                    _OverlayStat('Time', formatDuration(a.durationSeconds)),
                    const SizedBox(height: 28),
                    // ── Orange route shape ──────────────────────
                    if (a.routeCoordinates.length >= 2)
                      RouteOutlineWidget(
                        coordinates: a.routeCoordinates,
                        size: 160,
                      ),
                    const SizedBox(height: 14),
                    // App branding
                    const Text(
                      'STRAVA',
                      style: TextStyle(
                        color: Color(0xFFFC4C02),
                        fontSize: 22,
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

        // ── Top bar ─────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _retake,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: CupertinoColors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.arrow_counterclockwise,
                              color: CupertinoColors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Retake',
                              style: TextStyle(
                                  color: CupertinoColors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Use Photo button (bottom) ────────────────────────────────
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: CupertinoButton(
            color: const Color(0xFFFC4C02),
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(vertical: 16),
            onPressed: _usePhoto,
            child: const Text(
              'Use Photo',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

/// Large stat line for the dark picker state.
class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: CupertinoColors.systemGrey, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

/// Stats overlaid on the photo preview.
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
              fontSize: 15,
              fontWeight: FontWeight.w400,
              shadows: [Shadow(blurRadius: 6, color: CupertinoColors.black)],
            )),
        Text(value,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(blurRadius: 8, color: CupertinoColors.black)],
            )),
      ],
    );
  }
}


