import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:appwizard/core/config/attachment_limits.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// A screenshot prepared for the AI functions: downscaled JPEG, ready to base64.
class EncodedImage {
  const EncodedImage({required this.mimeType, required this.bytes});

  final String mimeType;
  final Uint8List bytes;

  String get base64Data => base64Encode(bytes);
}

/// One compression pass; swapped out in tests so they don't need the platform channel.
typedef CompressFile = Future<Uint8List?> Function(String path, {int minSide, int quality});

/// Shrinks a screenshot before it is uploaded: shorter side down to [minSide] px, JPEG
/// [quality], and never larger than [maxBytes] — if a pass comes back over budget it
/// re-runs with less quality, then a smaller side. Keeping the payload small is the
/// client's job; the function's caps are only a backstop.
///
/// Compression runs natively (flutter_image_compress), so it is off the UI thread and
/// far faster than decoding in Dart. EXIF rotation is applied, then stripped.
class ScreenshotEncoder {
  const ScreenshotEncoder({
    this.minSide = 720,
    this.quality = 80,
    this.maxBytes = AttachmentLimits.maxImageBytes,
    CompressFile compress = _nativeCompress,
  }) : _compress = compress;

  /// Target for the shorter side: a phone screenshot keeps its aspect, so a 1080×2400
  /// capture lands around 720×1600 — still readable to the model, a few hundred KB.
  final int minSide;
  final int quality;
  final int maxBytes;
  final CompressFile _compress;

  /// The retry loop stops here: below this a screenshot stops being legible, and a JPEG
  /// this small is far under any sane byte budget.
  static const int _floorQuality = 50;
  static const int _floorSide = 360;

  Future<EncodedImage> encode(String path) async {
    var side = minSide;
    var currentQuality = quality;
    while (true) {
      final bytes = await _compress(path, minSide: side, quality: currentQuality);
      if (bytes == null || bytes.isEmpty) throw const FormatException('Unsupported or corrupt image');
      if (bytes.length <= maxBytes || side <= _floorSide) {
        return EncodedImage(mimeType: 'image/jpeg', bytes: bytes);
      }
      // Quality first: text survives it better than fewer pixels do.
      if (currentQuality > _floorQuality) {
        currentQuality = _floorQuality;
      } else {
        side = math.max(_floorSide, (side * 3) ~/ 4);
      }
    }
  }

  static Future<Uint8List?> _nativeCompress(String path, {int minSide = 720, int quality = 80}) =>
      FlutterImageCompress.compressWithFile(
        path,
        minWidth: minSide,
        minHeight: minSide,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
}
