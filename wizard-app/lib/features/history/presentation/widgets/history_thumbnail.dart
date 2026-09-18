import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:appwizard/core/widgets/attachment_image.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// 52×68 history thumbnail: first screenshot / attachment, else diagonal stripes
/// (purple for Express, peach for text-only Pro deals).
class HistoryThumbnail extends StatelessWidget {
  const HistoryThumbnail({
    super.key,
    required this.conversation,
    this.width = 52,
    this.height = 68,
    this.radius = WizRadii.thumb,
  });

  final Conversation conversation;
  final double width;
  final double height;
  final double radius;

  static const Color _purpleA = Color(0xFFEEE8F6);
  static const Color _purpleB = Color(0xFFF7F3FB);
  static const Color _peachA = Color(0xFFFFEBDD);
  static const Color _peachB = Color(0xFFFFF5EC);

  @override
  Widget build(BuildContext context) {
    final isExpress = conversation.type == ConversationType.express;
    final placeholder = StripePlaceholder(
      colorA: isExpress ? _purpleA : _peachA,
      colorB: isExpress ? _purpleB : _peachB,
      icon: isExpress ? Icons.image_outlined : Icons.chat_bubble_outline_rounded,
    );
    final path = conversation.thumbnailPath;
    final child = path == null
        ? placeholder
        : AttachmentImage(
            path: path,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            placeholder: placeholder,
            errorWidget: placeholder,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

/// `repeating-linear-gradient(135deg, A 0 8px, B 8px 16px)` with a small centred icon.
class StripePlaceholder extends StatelessWidget {
  const StripePlaceholder({
    super.key,
    required this.colorA,
    required this.colorB,
    this.icon,
    this.stripe = 8,
  });

  final Color colorA;
  final Color colorB;
  final IconData? icon;
  final double stripe;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: DiagonalStripesPainter(colorA: colorA, colorB: colorB, stripe: stripe),
        child: icon == null
            ? null
            : Center(child: Icon(icon, size: 16, color: WizColors.textTertiary)),
      );
}

/// Diagonal stripes at [angleDeg] (CSS convention, 135° = towards bottom-right).
class DiagonalStripesPainter extends CustomPainter {
  const DiagonalStripesPainter({
    required this.colorA,
    required this.colorB,
    this.stripe = 8,
    this.angleDeg = 135,
  });

  final Color colorA;
  final Color colorB;
  final double stripe;
  final double angleDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final a = angleDeg * math.pi / 180;
    final period = stripe * 2;
    final shader = ui.Gradient.linear(
      Offset.zero,
      Offset(math.sin(a) * period, -math.cos(a) * period),
      [colorA, colorA, colorB, colorB],
      const [0, 0.5, 0.5, 1],
      TileMode.repeated,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(DiagonalStripesPainter oldDelegate) =>
      oldDelegate.colorA != colorA ||
      oldDelegate.colorB != colorB ||
      oldDelegate.stripe != stripe ||
      oldDelegate.angleDeg != angleDeg;
}
