import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/widgets.dart';

/// Handles capturing a widget as a PNG and sharing it via the system share sheet.
class ShareService {
  Rect _shareOriginFromKey(GlobalKey key) {
    final context = key.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final origin = renderObject.localToGlobal(Offset.zero);
      final width = renderObject.size.width <= 0 ? 1.0 : renderObject.size.width;
      final height =
          renderObject.size.height <= 0 ? 1.0 : renderObject.size.height;
      return Rect.fromLTWH(origin.dx, origin.dy, width, height);
    }
    // iOS requires a non-zero popover origin; use a tiny fallback rect.
    return const Rect.fromLTWH(1, 1, 1, 1);
  }

  /// Captures the widget bound to [key] as a PNG and opens the iOS share sheet.
  /// The [key] must be attached to a [RepaintBoundary].
  Future<void> shareActivityImage(GlobalKey key, {String? text}) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RepaintBoundary not found');

      // Capture at 3× pixel ratio for a crisp image on Retina displays
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final bytes = byteData.buffer.asUint8List();

      // Write to a temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/activity_share.png');
      await file.writeAsBytes(bytes);

      // Open the system share sheet
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text ?? 'Check out my run! 🏃',
        sharePositionOrigin: _shareOriginFromKey(key),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Shares the original photo file in full resolution.
  Future<void> shareOriginalPhoto(String photoPath, {String? text}) async {
    final file = File(photoPath);
    if (!file.existsSync()) {
      throw Exception('Photo file not found');
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: text ?? 'Check out my run! 🏃',
    );
  }

  /// Captures the widget bound to [key] as a transparent-background PNG
  /// and opens the iOS share sheet. Use this with [StickerOverlayWidget].
  /// [ImageByteFormat.png] preserves the alpha channel for transparency.
  Future<void> exportTransparentSticker(GlobalKey key, {String? text}) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RepaintBoundary not found');

      // 3× pixel ratio for Retina quality, PNG keeps alpha channel
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode sticker');

      final bytes = byteData.buffer.asUint8List();

      // Use a different filename to avoid colliding with shareActivityImage
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/activity_sticker.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text ?? 'Check out my run! 🏃',
        sharePositionOrigin: _shareOriginFromKey(key),
      );
    } catch (e) {
      rethrow;
    }
  }
}

