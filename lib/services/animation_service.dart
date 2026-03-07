import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures a frame of the animated route and shares it as a PNG.
/// Uses the same [RepaintBoundary] capture approach as [ShareService],
/// but targets the animated widget at its final completed state.
class AnimationService {
  /// Captures the widget attached to [key] at the current render frame
  /// and shares it via the system share sheet.
  Future<void> shareAnimationFrame(GlobalKey key, {String? text}) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RepaintBoundary not found');

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode frame');

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/activity_animation_frame.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text ?? 'Check out my run route! 🏃 #RunTracker',
      );
    } catch (e) {
      rethrow;
    }
  }
}

