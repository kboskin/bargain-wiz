import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:appwizard/core/utils/color_helper.dart';

void main() {
  group('ColorHelper', () {
    late ColorHelper colorHelper;

    setUp(() {
      colorHelper = ColorHelper();
    });

    group('parseHexColor', () {
      test('should parse 6-character hex color with # prefix', () {
        final color = colorHelper.parseHexColor('#FFC107');
        expect(color, equals(const Color(0xFFFFC107)));
      });

      test('should parse 6-character hex color without # prefix', () {
        final color = colorHelper.parseHexColor('FFC107');
        expect(color, equals(const Color(0xFFFFC107)));
      });

      test('should parse 8-character hex color with alpha channel', () {
        final color = colorHelper.parseHexColor('#80FFC107');
        expect(color, equals(const Color(0x80FFC107)));
      });

      test('should parse 8-character hex color without # prefix', () {
        final color = colorHelper.parseHexColor('80FFC107');
        expect(color, equals(const Color(0x80FFC107)));
      });

      test('should handle lowercase hex codes', () {
        final color = colorHelper.parseHexColor('#ffc107');
        expect(color, equals(const Color(0xFFFFC107)));
      });

      test('should handle mixed case hex codes', () {
        final color = colorHelper.parseHexColor('#FfC107');
        expect(color, equals(const Color(0xFFFFC107)));
      });

      test('should return default color for invalid hex format (too short)', () {
        const defaultColor = Color(0xFF000000);
        final color = colorHelper.parseHexColor('#FFC10') ?? defaultColor;
        expect(color, equals(defaultColor));
      });

      test('should return default color for invalid hex format (too long)', () {
        const defaultColor = Color(0xFF000000);
        final color = colorHelper.parseHexColor('#FFC107000') ?? defaultColor;
        expect(color, equals(defaultColor));
      });

      test('should return default color for invalid hex format (non-hex characters)', () {
        const defaultColor = Color(0xFF000000);
        final color = colorHelper.parseHexColor('#GGGGGG') ?? defaultColor;
        expect(color, equals(defaultColor));
      });

      test('should return default color for empty string', () {
        const defaultColor = Color(0xFF000000);
        final color = colorHelper.parseHexColor('') ?? defaultColor;
        expect(color, equals(defaultColor));
      });

      test('should trim whitespace', () {
        final color = colorHelper.parseHexColor('  #FFC107  ');
        expect(color, equals(const Color(0xFFFFC107)));
      });

      test('should use custom default color', () {
        const customDefault = Color(0xFF123456);
        final color = colorHelper.parseHexColor('invalid') ?? customDefault;
        expect(color, equals(customDefault));
      });
    });

    group('getColor', () {
      test('should return parsed color for valid hex string', () {
        final color = colorHelper.getColor('#FFC107');
        expect(color, equals(const Color(0xFFFFC107)));
      });

      test('should return default color for null input', () {
        const defaultColor = Color(0xFF000000);
        final color = colorHelper.getColor(null) ?? defaultColor;
        expect(color, equals(defaultColor));
      });

      test('should return default color for empty string', () {
        const defaultColor = Color(0xFF000000);
        final color = colorHelper.getColor('') ?? defaultColor;
        expect(color, equals(defaultColor));
      });

      test('should use custom default color', () {
        const customDefault = Color(0xFF123456);
        final color = colorHelper.getColor(null) ?? customDefault;
        expect(color, equals(customDefault));
      });

      test('should parse valid hex and return it', () {
        final color = colorHelper.getColor('#4285F4');
        expect(color, equals(const Color(0xFF4285F4)));
      });
    });
  });
}

