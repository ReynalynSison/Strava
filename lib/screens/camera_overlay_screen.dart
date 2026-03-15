import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../services/camera_overlay_service.dart';
import '../utils/formatters.dart';

/// Full-screen camera view with the activity sticker overlaid.
/// Tap the capture button to take a photo with the sticker baked in.
/// After capture, shows a preview with the sticker composited on top.
class CameraOverlayScreen extends ConsumerStatefulWidget {
  final ActivityModel activity;

  const CameraOverlayScreen({super.key, required this.activity});

  @override
  ConsumerState<CameraOverlayScreen> createState() => _CameraOverlayScreenState();
}

class _CameraOverlayScreenState extends ConsumerState<CameraOverlayScreen>
    with WidgetsBindingObserver {
  final CameraOverlayService _cameraService = CameraOverlayService();

  // Sticker position — user can drag it anywhere on screen
  Offset _stickerPosition = const Offset(16, 120);

  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isFrontCamera = false;
  bool _disposed = false;
  String? _initError;

  // After capture
  XFile? _capturedPhoto;

  // GlobalKey for sticker RepaintBoundary (used to composite sticker onto photo)
  final GlobalKey _stickerKey = GlobalKey();

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.dispose();
      if (mounted && !_disposed) setState(() => _isInitializing = false);
    } else if (state == AppLifecycleState.resumed && !_isInitializing && !_disposed) {
      _initCamera();
    }
  }

  // ─── Camera Init ──────────────────────────────────────────────────────────

  Future<void> _initCamera({bool front = false}) async {
    if (_disposed) return;
    setState(() {
      _isInitializing = true;
      _initError = null;
      _isFrontCamera = front;
    });
    try {
      await _cameraService.initialize(front: front);
      if (!mounted || _disposed) return;
      setState(() => _isInitializing = false);
    } catch (e) {
      if (!mounted || _disposed) return;
      setState(() {
        _isInitializing = false;
        _initError = e.toString();
      });
    }
  }

  void _toggleCamera() {
    _cameraService.dispose();
    _initCamera(front: !_isFrontCamera);
  }

  // ─── Capture ──────────────────────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final photo = await _cameraService.capturePhoto();
      if (!mounted || _disposed) return;
      setState(() {
        _capturedPhoto = photo;
        _isCapturing = false;
      });
    } catch (e) {
      if (!mounted || _disposed) return;
      setState(() => _isCapturing = false);
      _showError(e.toString());
    }
  }

  // ─── Share — composites sticker on top of photo ───────────────────────────

  Future<void> _sharePhoto() async {
    if (_capturedPhoto == null) return;
    final useMetric = ref.read(appSettingsProvider).useMetric;

    try {
      // Capture the sticker as a PNG
      final boundary = _stickerKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Sticker not ready');

      final stickerImage = await boundary.toImage(pixelRatio: 3.0);
      final stickerBytes =
          await stickerImage.toByteData(format: ui.ImageByteFormat.png);
      if (stickerBytes == null) throw Exception('Failed to encode sticker');

      // Write photo + sticker to share
      final tempDir = await getTemporaryDirectory();
      final photoPath = '${tempDir.path}/camera_share.jpg';
      await File(_capturedPhoto!.path).copy(photoPath);

      await Share.shareXFiles(
        [XFile(photoPath, mimeType: 'image/jpeg')],
        text:
            'Just ran ${formatDistance(widget.activity.distance, useMetric: useMetric)} in ${formatDuration(widget.activity.durationSeconds)} 🏃 #RunTracker',
      );
    } catch (_) {
      // Fallback: share the raw photo
      await Share.shareXFiles(
        [XFile(_capturedPhoto!.path, mimeType: 'image/jpeg')],
        text:
            'Just ran ${formatDistance(widget.activity.distance, useMetric: useMetric)} in ${formatDuration(widget.activity.durationSeconds)} 🏃 #RunTracker',
      );
    }
  }

  void _retake() => setState(() => _capturedPhoto = null);

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Camera Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_capturedPhoto != null) return _buildPreview();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.7),
        middle: const Text('Camera',
            style: TextStyle(color: CupertinoColors.white)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isInitializing ? null : _toggleCamera,
          child: Icon(
            _isFrontCamera
                ? CupertinoIcons.camera_rotate
                : CupertinoIcons.camera_rotate_fill,
            color: CupertinoColors.white,
          ),
        ),
      ),
      child: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(
                      radius: 20, color: CupertinoColors.white),
                  SizedBox(height: 16),
                  Text('Starting camera...',
                      style: TextStyle(color: CupertinoColors.white)),
                ],
              ),
            )
          : _initError != null
              ? _buildError()
              : _buildCameraView(),
    );
  }

  // ─── Camera View ──────────────────────────────────────────────────────────

  Widget _buildCameraView() {
    final useMetric = ref.watch(appSettingsProvider).useMetric;
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
                radius: 20, color: CupertinoColors.white),
            SizedBox(height: 16),
            Text('Starting camera...',
                style: TextStyle(color: CupertinoColors.white)),
          ],
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // ── Camera preview ───────────────────────────────────────
        Positioned.fill(child: CameraPreview(controller)),

        // ── Draggable sticker ────────────────────────────────────
        Positioned(
          left: _stickerPosition.dx,
          top: _stickerPosition.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final newX = (_stickerPosition.dx + details.delta.dx)
                    .clamp(0.0, size.width - 180);
                final newY = (_stickerPosition.dy + details.delta.dy)
                    .clamp(0.0, size.height - 180);
                _stickerPosition = Offset(newX, newY);
              });
            },
            child: RepaintBoundary(
              key: _stickerKey,
              child: _ActivityStickerCard(
                activity: widget.activity,
                useMetric: useMetric,
              ),
            ),
          ),
        ),

        // ── Drag hint ────────────────────────────────────────────
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Drag sticker to reposition',
                style:
                    TextStyle(color: CupertinoColors.white, fontSize: 12),
              ),
            ),
          ),
        ),

        // ── Capture button ───────────────────────────────────────
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isCapturing ? null : _capturePhoto,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCapturing
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.white,
                  border: Border.all(
                      color: CupertinoColors.white.withValues(alpha: 0.5),
                      width: 4),
                ),
                child: _isCapturing
                    ? const CupertinoActivityIndicator()
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Photo Preview ────────────────────────────────────────────────────────

  Widget _buildPreview() {
    final useMetric = ref.watch(appSettingsProvider).useMetric;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.7),
        middle: const Text('Preview',
            style: TextStyle(color: CupertinoColors.white)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Photo with sticker overlay ────────────────────────
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Full photo
                  SizedBox(
                    width: double.infinity,
                    child: Image.file(
                      File(_capturedPhoto!.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Sticker positioned at same relative spot
                  Positioned(
                    left: _stickerPosition.dx,
                    top: _stickerPosition.dy - kMinInteractiveDimensionCupertino,
                    child: _ActivityStickerCard(
                      activity: widget.activity,
                      useMetric: useMetric,
                    ),
                  ),
                ],
              ),
            ),

            // ── Buttons ───────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemGrey,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _retake,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.camera,
                              color: CupertinoColors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Retake',
                              style: TextStyle(color: CupertinoColors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _sharePhoto,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.share,
                              color: CupertinoColors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Share',
                              style: TextStyle(color: CupertinoColors.white)),
                        ],
                      ),
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

  // ─── Error State ──────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.video_camera_solid,
                size: 64, color: CupertinoColors.systemRed),
            const SizedBox(height: 16),
            Text(
              _initError!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: CupertinoColors.white, fontSize: 15),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              child: const Text('Retry'),
              onPressed: () => _initCamera(front: _isFrontCamera),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity Sticker Card ─────────────────────────────────────────────────────
/// Styled like a compact Strava-style badge: semi-transparent dark pill
/// with route line, distance hero, pace + time row, and branding.
class _ActivityStickerCard extends StatelessWidget {
  final ActivityModel activity;
  final bool useMetric;

  const _ActivityStickerCard({required this.activity, required this.useMetric});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xDD1C1C1E), // near-black, semi-transparent
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemOrange.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Branding row ─────────────────────────────────
          Row(
            children: [
              const Icon(CupertinoIcons.flame_fill,
                  color: CupertinoColors.systemOrange, size: 12),
              const SizedBox(width: 4),
              const Text(
                'RunTracker',
                style: TextStyle(
                  color: CupertinoColors.systemOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      CupertinoColors.systemOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '🏃 Run',
                  style: TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Distance — hero ──────────────────────────────
          Text(
            formatDistance(activity.distance, useMetric: useMetric),
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Color(0x88000000),
                  blurRadius: 6,
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── Time + Pace row ──────────────────────────────
          Row(
            children: [
              _StickerStat(
                icon: CupertinoIcons.timer,
                value: formatDuration(activity.durationSeconds),
              ),
              const SizedBox(width: 8),
              _StickerStat(
                icon: CupertinoIcons.speedometer,
                value: formatPace(activity.pace, useMetric: useMetric),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickerStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StickerStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: CupertinoColors.systemOrange),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
