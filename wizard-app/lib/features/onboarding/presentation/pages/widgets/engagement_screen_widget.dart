import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';

/// `engagement` template (retired from the default order, kept as a template):
/// centred visual, Outfit 34 title and Figtree 17 description.
class EngagementScreenWidget extends StatelessWidget {
  const EngagementScreenWidget({required this.model, super.key, this.textColor = WizColors.ink});

  final EngagementScreenModel model;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final highlightColor = wizHexColor(model.effectiveHighlightColor);
    final description = TemplateText.textOf(context, model.description);
    final width = model.metadata?.width ?? 200.0;
    final height = model.metadata?.height ?? 200.0;
    final visual = model.visual;
    return OnboardingScrollFill(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (visual == null || visual.endsWith(WizMascot.asset.split('/').last))
                  WizMascot(width: width)
                else
                  VisualAssetWidget(visualPath: visual, width: width, height: height),
                const SizedBox(height: 24),
                HighlightedText(
                  TemplateText.textOf(context, model.title),
                  style: WizType.headline.copyWith(color: textColor),
                  highlights: model.titleHighlights,
                  defaultHighlightColor: highlightColor,
                  boldColor: textColor,
                  textAlign: TextAlign.center,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  HighlightedText(
                    description,
                    style: WizType.bodyLg,
                    highlights: model.descriptionHighlights,
                    defaultHighlightColor: highlightColor,
                    highlightWeight: FontWeight.w600,
                    boldColor: textColor,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
