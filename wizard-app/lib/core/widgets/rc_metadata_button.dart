import 'package:flutter/material.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/button_style.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/data/models/remote_config/button_config.dart';

/// Button widget that uses ButtonConfig from Remote Config metadata
class RCMetadataButton extends StatefulWidget {
  final ButtonConfig config;
  final VoidCallback? onPressed;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final TextStyle? textStyle;
  final ColorHelper? colorHelper;
  final MultilocaleTextHelper? multilocaleTextHelper;

  const RCMetadataButton({
    super.key,
    required this.config,
    this.onPressed,
    this.isLoading = false,
    this.padding,
    this.borderRadius,
    this.textStyle,
    this.colorHelper,
    this.multilocaleTextHelper,
  });

  @override
  State<RCMetadataButton> createState() => _RCMetadataButtonState();
}

class _RCMetadataButtonState extends State<RCMetadataButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowPulseAnimation;
  late Animation<double> _scalePulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation if glow pulse is enabled
    if (widget.config.glowPulse ?? false) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );
      
      // Create a smooth glow pulse animation that goes from 0.5 to 1.0
      _glowPulseAnimation = Tween<double>(
        begin: 0.5,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ),
      );
      
      // Create a scale pulse animation that goes from 1.0 to 1.05 (5% larger)
      _scalePulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.05,
      ).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ),
      );
      
      // Repeat the animation
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.config.glowPulse ?? false) {
      _pulseController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cachedMultilocaleTextHelper = widget.multilocaleTextHelper ?? di.sl<MultilocaleTextHelper>();

    // Get button text
    final buttonText = _getButtonText(cachedMultilocaleTextHelper);

    // Get colors - only parse if provided, no default fallback
    Color? buttonColor;
    Color? glowColor;

    if (widget.config.buttonColor != null && widget.config.buttonColor!.isNotEmpty) {
      final hexCode = widget.config.buttonColor!.replaceAll('#', '').trim();
      if (RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
        try {
          final fullHex = hexCode.length == 6 ? 'FF$hexCode' : hexCode;
          buttonColor = Color(int.parse(fullHex, radix: 16));
        } catch (e) {
          // If parsing fails, buttonColor remains null (no color applied)
        }
      }
    }

    if (widget.config.glowColor != null && widget.config.glowColor!.isNotEmpty) {
      final hexCode = widget.config.glowColor!.replaceAll('#', '').trim();
      if (RegExp(r'^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$').hasMatch(hexCode)) {
        try {
          final fullHex = hexCode.length == 6 ? 'FF$hexCode' : hexCode;
          glowColor = Color(int.parse(fullHex, radix: 16));
        } catch (e) {
          // If parsing fails, glowColor remains null (no glow applied)
        }
      }
    }

    final baseGlowIntensity = widget.config.glowIntensity ?? 0.6;
    
    // Calculate animated glow intensity if pulsing is enabled
    double glowIntensity = baseGlowIntensity;
    if ((widget.config.glowPulse ?? false) && glowColor != null) {
      glowIntensity = baseGlowIntensity * _glowPulseAnimation.value;
    }

    // Build button
    Widget button = ElevatedButton(
      onPressed: widget.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
        ),
        elevation: 0,
        disabledBackgroundColor: buttonColor?.withValues(alpha: 0.5),
      ),
      child: widget.isLoading
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
              style: widget.textStyle ??
                  const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
            ),
    );

    // Apply styling based on button style enum
    switch (widget.config.buttonStyle) {
      case ButtonVisualStyle.glow:
        if (widget.onPressed != null && glowColor != null) {
          final effectiveGlowColor = glowColor; // Capture non-null value
          // Use AnimatedBuilder if pulsing is enabled, otherwise use static DecoratedBox
          if (widget.config.glowPulse ?? false) {
            button = AnimatedBuilder(
              animation: _pulseController,
              builder: (final BuildContext context, final Widget? child) {
                final animatedIntensity = baseGlowIntensity * _glowPulseAnimation.value;
                return Transform.scale(
                  scale: _scalePulseAnimation.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
                      boxShadow: [
                        BoxShadow(
                          color: effectiveGlowColor.withValues(alpha: animatedIntensity),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: effectiveGlowColor.withValues(alpha: animatedIntensity * 0.6),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
              child: button,
            );
          } else {
            button = DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
                boxShadow: [
                  BoxShadow(
                    color: effectiveGlowColor.withValues(alpha: glowIntensity),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: effectiveGlowColor.withValues(alpha: glowIntensity * 0.6),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: button,
            );
          }
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

  String _getButtonText(final MultilocaleTextHelper multilocaleTextHelper) {
    if (widget.config.text == null) {
      return 'Button';
    }
    if (widget.config.text is String) {
      return widget.config.text as String;
    } else if (widget.config.text is Map<String, dynamic>) {
      return multilocaleTextHelper.getText(context, widget.config.text);
    }
    return 'Button';
  }
}

