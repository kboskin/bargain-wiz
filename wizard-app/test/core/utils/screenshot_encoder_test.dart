import 'dart:typed_data';

import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the compressor was asked for and answers with a payload of [sizes] bytes,
/// one per pass, so the retry loop can be driven without the platform channel.
class _FakeCompressor {
  _FakeCompressor(this.sizes);

  final List<int> sizes;
  final calls = <({int minSide, int quality})>[];

  Future<Uint8List?> call(String path, {int minSide = 720, int quality = 80}) async {
    calls.add((minSide: minSide, quality: quality));
    final size = sizes[calls.length.clamp(1, sizes.length) - 1];
    return size < 0 ? null : Uint8List(size);
  }
}

void main() {
  group('ScreenshotEncoder', () {
    test('sends the first pass when it is inside the budget', () async {
      final compressor = _FakeCompressor([300000]);
      final out = await ScreenshotEncoder(compress: compressor.call).encode('shot.jpg');
      expect(out.mimeType, 'image/jpeg');
      expect(out.bytes.length, 300000);
      expect(out.base64Data, isNotEmpty);
      expect(compressor.calls, [(minSide: 720, quality: 80)]);
    });

    test('drops quality, then the side, until the image fits', () async {
      final compressor = _FakeCompressor([900000, 700000, 400000]);
      final out = await ScreenshotEncoder(compress: compressor.call, maxBytes: 500000).encode('shot.jpg');
      expect(out.bytes.length, 400000);
      expect(compressor.calls, [
        (minSide: 720, quality: 80),
        (minSide: 720, quality: 50),
        (minSide: 540, quality: 50),
      ]);
    });

    test('stops shrinking at the floor instead of looping forever', () async {
      final compressor = _FakeCompressor([900000]);
      final out = await ScreenshotEncoder(compress: compressor.call, maxBytes: 1).encode('shot.jpg');
      expect(out.bytes, isNotEmpty);
      expect(compressor.calls.last.minSide, 360);
    });

    test('rejects data the compressor could not read', () async {
      final compressor = _FakeCompressor([-1]);
      expect(
        () => ScreenshotEncoder(compress: compressor.call).encode('broken.jpg'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
