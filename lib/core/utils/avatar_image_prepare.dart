import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';

/// Prepares gallery picks for circular profile avatars.
///
/// Trims letterbox/pillarbox bars, then center-crops to a square JPEG that
/// fills a circular avatar without black side strips.
class AvatarImagePrepare {
  const AvatarImagePrepare._();

  static const int outputSize = 768;
  static const int jpegQuality = 90;

  /// Near-black / near-navy pixels treated as empty letterbox bars.
  static const int _darkThreshold = 40;

  /// A row/column is a border if at least this fraction of pixels are dark.
  static const double _borderDarkRatio = 0.92;

  /// Center-crop [bytes] to a square JPEG suitable for avatars.
  static Future<Uint8List> toSquareJpeg(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Cannot prepare empty image.');
    }

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src = frame.image;
    try {
      final srcW = src.width;
      final srcH = src.height;
      if (srcW <= 0 || srcH <= 0) {
        throw ArgumentError('Invalid image dimensions.');
      }

      final content = await _contentBounds(src);
      final cropW = content.width;
      final cropH = content.height;
      final side = math.min(cropW, cropH).toDouble();
      final ox = content.left + (cropW - side) / 2.0;
      final oy = content.top + (cropH - side) / 2.0;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // Opaque fill so any edge antialias never becomes JPEG "black holes".
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      final dest = ui.Rect.fromLTWH(
        0,
        0,
        outputSize.toDouble(),
        outputSize.toDouble(),
      );
      final source = ui.Rect.fromLTWH(ox, oy, side, side);
      canvas.drawImageRect(
        src,
        source,
        dest,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outputSize, outputSize);
      try {
        final pngBytes = await cropped.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (pngBytes == null) {
          throw ArgumentError('Could not encode profile image.');
        }

        final jpeg = await FlutterImageCompress.compressWithList(
          pngBytes.buffer.asUint8List(),
          minWidth: outputSize,
          minHeight: outputSize,
          quality: jpegQuality,
          format: CompressFormat.jpeg,
        );
        if (jpeg.isEmpty || !ImageStorageService.isJpegBytes(jpeg)) {
          throw ArgumentError('Could not convert profile image to JPEG.');
        }
        // Ensure under Storage upload cap (complex photos at q90 can exceed 1MB).
        if (jpeg.length > ImageStorageService.maxUploadBytes) {
          return ImageStorageService.ensureJpegBytes(jpeg);
        }
        return jpeg;
      } finally {
        cropped.dispose();
      }
    } finally {
      src.dispose();
    }
  }

  /// Bounding box of non-letterbox content (strips uniform dark edges).
  static Future<ui.Rect> _contentBounds(ui.Image src) async {
    final w = src.width;
    final h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) {
      return ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    }
    final px = bd.buffer.asUint8List();

    bool isDark(int x, int y) {
      final i = (y * w + x) * 4;
      final r = px[i];
      final g = px[i + 1];
      final b = px[i + 2];
      return r <= _darkThreshold &&
          g <= _darkThreshold &&
          b <= _darkThreshold;
    }

    bool rowIsBorder(int y) {
      var dark = 0;
      for (var x = 0; x < w; x++) {
        if (isDark(x, y)) dark++;
      }
      return dark / w >= _borderDarkRatio;
    }

    bool colIsBorder(int x) {
      var dark = 0;
      for (var y = 0; y < h; y++) {
        if (isDark(x, y)) dark++;
      }
      return dark / h >= _borderDarkRatio;
    }

    var top = 0;
    var bottom = h - 1;
    var left = 0;
    var right = w - 1;

    while (top < bottom && rowIsBorder(top)) {
      top++;
    }
    while (bottom > top && rowIsBorder(bottom)) {
      bottom--;
    }
    while (left < right && colIsBorder(left)) {
      left++;
    }
    while (right > left && colIsBorder(right)) {
      right--;
    }

    final bw = right - left + 1;
    final bh = bottom - top + 1;
    // If trim failed (solid dark image / weird art), use full frame.
    if (bw < 16 || bh < 16) {
      return ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    }
    return ui.Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      bw.toDouble(),
      bh.toDouble(),
    );
  }
}
