import 'dart:math' as math;

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/services/store_review_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';

/// `permission` template: Lottie 180, centred title/description, teal glow primary +
/// grey secondary button. Behaviour depends on `subtype`:
///
/// - `notifications` (default): primary asks for push permission (bell Lottie).
/// - `rate_us`: primary opens the native store review prompt (star Lottie), then
///   continues; secondary just continues. Used as the "rate us" onboarding step.
///
/// Button labels come from `metadata.buttons[].text`; an `action` containing
/// "allow" / "permission" / "rate" / "review" marks the primary button, anything else the
/// secondary. `metadata.button_visual` (e.g. the wand Lottie) is shown inside the primary.
class PermissionScreenWidget extends StatefulWidget {
  const PermissionScreenWidget({
    required this.model,
    super.key,
    this.textColor = WizColors.ink,
    this.onContinue,
  });

  static const String rateUsSubtype = 'rate_us';
  static const String notificationsVisual = 'assets/lottie/notification.json';
  static const String rateUsVisual = 'assets/lottie/star_anim.json';

  final PermissionScreenModel model;
  final Color textColor;
  final VoidCallback? onContinue;

  @override
  State<PermissionScreenWidget> createState() => _PermissionScreenWidgetState();
}

class _PermissionScreenWidgetState extends State<PermissionScreenWidget> {
  bool _busy = false;

  bool get _isRateUs => widget.model.subtype.toLowerCase() == PermissionScreenWidget.rateUsSubtype;

  Future<void> _primary() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_isRateUs) {
        await StoreReview.request();
      } else {
        await FirebaseService.requestNotificationPermission();
      }
    } on Object catch (e, st) {
      di.sl<AppLogger>().e('Permission screen primary action failed (${widget.model.subtype})', e, st);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onContinue?.call();
  }

  static bool _isPrimaryAction(String action) =>
      (action.contains('allow') && !action.contains('deny')) ||
      action.contains('permission') ||
      action.contains('rate') ||
      action.contains('review');

  ({String primary, String secondary}) _labels(BuildContext context) {
    var primary = _isRateUs ? 'Rate us' : 'Allow';
    var secondary = _isRateUs ? 'Not now' : "Don't Allow";
    final buttons = widget.model.metadata?.buttons ?? const [];
    for (final b in buttons.whereType<Map>()) {
      final action = b['action']?.toString().toLowerCase() ?? '';
      final text = TemplateText.textOf(context, b['text']);
      if (text.isEmpty) continue;
      if (_isPrimaryAction(action)) {
        primary = text;
      } else {
        secondary = text;
      }
    }
    final legacy = TemplateText.textOf(context, widget.model.metadata?.buttonText);
    if (buttons.isEmpty && legacy.isNotEmpty) primary = legacy;
    return (primary: primary, secondary: secondary);
  }

  /// Small Lottie inside the primary button (`metadata.button_visual`, e.g. the wand).
  Widget? _buttonVisual() {
    final path = widget.model.metadata?.buttonVisual;
    if (path == null || path.isEmpty) return null;
    final size = math.min(30.0, widget.model.metadata?.buttonVisualWidth ?? 28.0);
    return VisualAssetWidget(visualPath: path, width: size, height: size);
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels(context);
    final highlightColor = wizHexColor(widget.model.effectiveHighlightColor);
    final visual = widget.model.visual ??
        (_isRateUs ? PermissionScreenWidget.rateUsVisual : PermissionScreenWidget.notificationsVisual);
    final size = widget.model.metadata?.width ?? 180;
    return OnboardingScrollFill(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VisualAssetWidget(visualPath: visual, width: size, height: widget.model.metadata?.height ?? size),
                const SizedBox(height: 8),
                HighlightedText(
                  TemplateText.textOf(context, widget.model.title),
                  style: WizType.titleXl.copyWith(color: widget.textColor),
                  highlights: widget.model.titleHighlights,
                  defaultHighlightColor: highlightColor,
                  boldColor: widget.textColor,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: HighlightedText(
                    TemplateText.textOf(context, widget.model.description),
                    style: WizType.bodySecondary,
                    highlights: widget.model.descriptionHighlights,
                    defaultHighlightColor: highlightColor,
                    highlightWeight: FontWeight.w600,
                    boldColor: widget.textColor,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: WizGlowButton.grey(label: labels.secondary, height: 56, onPressed: widget.onContinue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WizGlowButton(
                label: labels.primary,
                leading: _buttonVisual(),
                onPressed: _busy ? null : _primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
