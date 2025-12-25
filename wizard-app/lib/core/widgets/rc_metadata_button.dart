import 'package:flutter/material.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/button_style.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/data/models/remote_config/button_config.dart';

/// Button widget that uses ButtonConfig from Remote Config metadata
class RCMetadataButton extends StatelessWidget {
  final ButtonConfig config;
  final VoidCallback? onPressed;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final TextStyle? textStyle;
  final ColorHelper? colorHelper;
  final MultilocaleTextHelper? multilocaleTextHelper;
  final BuildContext context;

  const RCMetadataButton({
    super.key,
    required this.config,
    required this.context,
    this.onPressed,
    this.isLoading = false,
    this.padding,
    this.borderRadius,
    this.textStyle,
    this.colorHelper,
    this.multilocaleTextHelper,
  });

  @override
  Widget build(BuildContext context) {
    final cachedColorHelper = colorHelper ?? di.sl<ColorHelper>();
    final cachedMultilocaleTextHelper = multilocaleTextHelper ?? di.sl<MultilocaleTextHelper>();

    // Get button text
    final buttonText = _getButtonText(cachedMultilocaleTextHelper);

    // Get colors - only parse if provided, no default fallback
    Color? buttonColor;
    Color? glowColor;

    if (config.buttonColor != null && config.buttonColor!.isNotEmpty) {
      final hexCode = config.buttonColor!.replaceAll('#', '').trim();
      if (RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
        try {
          final fullHex = hexCode.length == 6 ? 'FF$hexCode' : hexCode;
          buttonColor = Color(int.parse(fullHex, radix: 16));
        } catch (e) {
          // If parsing fails, buttonColor remains null (no color applied)
        }
      }
    }

    if (config.glowColor != null && config.glowColor!.isNotEmpty) {
      final hexCode = config.glowColor!.replaceAll('#', '').trim();
      if (RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
        try {
          final fullHex = hexCode.length == 6 ? 'FF$hexCode' : hexCode;
          glowColor = Color(int.parse(fullHex, radix: 16));
        } catch (e) {
          // If parsing fails, glowColor remains null (no glow applied)
        }
      }
    }

    final glowIntensity = config.glowIntensity ?? 0.6;

    // Build button
    Widget button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 16),
        ),
        elevation: 0,
        disabledBackgroundColor: buttonColor?.withValues(alpha: 0.5),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              buttonText,
              style: textStyle ??
                  const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
            ),
    );

    // Apply styling based on button style enum
    switch (config.buttonStyle) {
      case ButtonVisualStyle.glow:
        if (onPressed != null && glowColor != null) {
          button = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius ?? 16),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: glowIntensity),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: glowIntensity * 0.6),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: button,
          );
        }
        break;
      case ButtonVisualStyle.gradient:
        // TODO: Implement gradient style if needed
        break;
      case ButtonVisualStyle.flat:
        // Flat style - no special effects
        break;
      case ButtonVisualStyle.outlined:
        // TODO: Implement outlined style if needed
        break;
    }

    return button;
  }

  String _getButtonText(MultilocaleTextHelper multilocaleTextHelper) {
    if (config.text == null) {
      return 'Button';
    }
    if (config.text is String) {
      return config.text as String;
    } else if (config.text is Map<String, dynamic>) {
      return multilocaleTextHelper.getText(context, config.text);
    }
    return 'Button';
  }
}

