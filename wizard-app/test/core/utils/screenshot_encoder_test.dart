import 'dart:typed_data';

import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _png(int width, int height) => Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

void main() {
  group('ScreenshotEncoder.encodeBytes', () {
    test('downscales the longest side and re-encodes as JPEG', () {
      final out = ScreenshotEncoder.encodeBytes(_png(2000, 1000), maxSide: 1280);
      expect(out.mimeType, 'image/jpeg');
      expect(out.width, 1280);
      expect(out.height, 640);
      expect(out.bytes, isNotEmpty);
      expect(out.base64Data, isNotEmpty);
      expect(img.decodeJpg(out.bytes)!.width, 1280);
    });

    test('portrait screenshots are limited by height', () {
      final out = ScreenshotEncoder.encodeBytes(_png(1080, 2400), maxSide: 1280);
      expect(out.height, 1280);
      expect(out.width, 576);
    });

    test('small images keep their size', () {
      final out = ScreenshotEncoder.encodeBytes(_png(300, 200));
      expect((out.width, out.height), (300, 200));
    });

    test('rejects data that is not an image', () {
      expect(() => ScreenshotEncoder.encodeBytes(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });
  });
}
