import 'package:camera/camera.dart';

/// Manages camera initialization, photo capture, and lifecycle.
/// One instance per [CameraOverlayScreen] — dispose() must be called on pop.
class CameraOverlayService {
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  // ─── Initialize ───────────────────────────────────────────────────────────

  /// Initializes the camera. Set [front] = true for selfie camera.
  /// Throws if no camera is available.
  Future<void> initialize({bool front = false}) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No camera available on this device');

    // Pick front or back camera
    final direction =
        front ? CameraLensDirection.front : CameraLensDirection.back;
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
  }

  // ─── Capture ──────────────────────────────────────────────────────────────

  /// Takes a photo and returns the [XFile] pointing to the saved image.
  Future<XFile> capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    if (_controller!.value.isTakingPicture) {
      throw Exception('Already taking a picture');
    }
    return await _controller!.takePicture();
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  /// Releases the camera. Must be called when the screen is popped.
  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}

