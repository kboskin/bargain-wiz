import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A screenshot prepared for the AI functions: downscaled JPEG, ready to base64.
class EncodedImage {
  const EncodedImage({required this.mimeType, required this.bytes, required this.width, required this.height});

  final String mimeType;
  final Uint8List bytes;
  final int width;
  final int height;

  String get base64Data => base64Encode(bytes);
}

/// Downscales screenshots before upload so a request stays small (the function caps
/// each image at 1.5 MB) and the model bill stays low: longest side [maxSide] px, JPEG
/// [quality]. Decoding runs off the UI thread.
class ScreenshotEncoder {
  const ScreenshotEncoder({this.maxSide = 1280, this.quality = 80});

  final int maxSide;
  final int quality;

  Future<EncodedImage> encode(String path) async {
    final bytes = await File(path).readAsBytes();
    return compute(_encodeJob, _EncodeJob(bytes, maxSide, quality));
  }

  /// Pure function used by [encode]; exposed for tests and callers that already hold bytes.
  static EncodedImage encodeBytes(Uint8List bytes, {int maxSide = 1280, int quality = 80}) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on Object {
      decoded = null;
    }
    if (decoded == null) throw const FormatException('Unsupported or corrupt image');
    // Camera photos carry EXIF rotation; apply it so the model sees upright text.
    var image = img.bakeOrientation(decoded);
    final longest = math.max(image.width, image.height);
    if (longest > maxSide) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? maxSide : null,
        height: image.height > image.width ? maxSide : null,
        interpolation: img.Interpolation.average,
      );
    }
    final jpg = img.encodeJpg(image, quality: quality);
    return EncodedImage(
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(jpg),
      width: image.width,
      height: image.height,
    );
  }
}

class _EncodeJob {
  const _EncodeJob(this.bytes, this.maxSide, this.quality);

  final Uint8List bytes;
  final int maxSide;
  final int quality;
}

EncodedImage _encodeJob(_EncodeJob job) =>
    ScreenshotEncoder.encodeBytes(job.bytes, maxSide: job.maxSide, quality: job.quality);
