import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/store_review_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_sheet.dart';
import 'package:appwizard/features/home/data/models/rate_us_modal_config.dart';
import 'package:appwizard/features/shared/data/models/remote_config/button_config.dart';
import 'package:appwizard/features/home/presentation/widgets/highlighted_text.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// "Are you satisfied?" dialog (README §10): star_anim 90, Outfit 26 title with teal word,
/// grey "No" → Feedback form, pulsing teal "Yes" → store review. The Yes button shows the
/// configured `button_visual` Lottie (wand) when present, otherwise a ✨ suffix.
class RateUsDialog extends StatelessWidget {
  const RateUsDialog({super.key, this.config});

  final RateUsModalConfig? config;

  /// Used when `rate_us_modal_config` names no size of its own.
  static const double _defaultVisualSize = 90;

  static const String _defaultVisual = 'assets/lottie/star_anim.json';

  static Future<void> show(BuildContext context) {
    final config = di.sl<RemoteConfigService>().getRateUsModalConfig();
    return WizDialog.show<void>(context, builder: (_) => RateUsDialog(config: config));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = TemplateText.textOf(context, config?.title, fallback: l10n.areYouSatisfied);
    final buttons = config?.buttons ?? const [];
    final noLabel = buttons.isNotEmpty ? TemplateText.textOf(context, buttons[0].text, fallback: l10n.no) : l10n.no;
    final yesRaw = buttons.length > 1 ? TemplateText.textOf(context, buttons[1].text, fallback: l10n.yes) : l10n.yes;
    final yesButton = buttons.length > 1 ? buttons[1] : null;
    final yesVisual = _buttonVisual(yesButton);
    final yesLabel = yesVisual != null || yesRaw.contains('✨') ? yesRaw : '$yesRaw ✨';
    final visual = (config?.visual ?? '').isNotEmpty ? config!.visual! : _defaultVisual;
    final highlightColor = HighlightedText.parseHexColor(config?.highlightColor) ?? WizColors.tealText;

    return WizDialog(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: VisualAssetWidget(
              visualPath: visual,
              width: config?.visualWidth ?? _defaultVisualSize,
              height: config?.visualHeight ?? _defaultVisualSize,
            ),
          ),
          const SizedBox(height: 6),
          HighlightedText(
            title,
            textAlign: TextAlign.center,
            style: WizType.titleMd,
            highlights: config?.highlightWords,
            defaultHighlightColor: highlightColor,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: WizGlowButton.grey(
                  label: noLabel,
                  onPressed: () {
                    // Resolve the router before the dialog context is torn down by pop().
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push(AppRoutes.feedback);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WizGlowButton(
                  label: yesLabel,
                  height: 52,
                  leading: yesVisual,
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await requestStoreReview();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens the native in-app review prompt when the store supports it.
  static Future<void> requestStoreReview() => StoreReview.request();

  /// Small Lottie inside a glow button (`button_visual`, e.g. magic_stick_pointer).
  static Widget? _buttonVisual(ButtonConfig? button) {
    final path = button?.buttonVisual;
    if (path == null || path.isEmpty) return null;
    final size = math.min(30.0, button!.buttonVisualWidth ?? 28.0);
    return VisualAssetWidget(visualPath: path, width: size, height: size);
  }
}
