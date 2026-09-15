import 'package:appwizard/core/config/wiz_catalog.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_profile_snapshot.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';

/// `warmup` template — the personalized mirror: monthly leak title, summary
/// chips, body copy with placeholders and the falling-money Lottie. All values
/// come from the answers collected *in this flow* ([answersByKey]).
class WarmupScreenWidget extends StatelessWidget {
  const WarmupScreenWidget({
    required this.model,
    super.key,
    this.answersByKey = const {},
    this.textColor = WizColors.ink,
    this.catalog,
  });

  final WarmupScreenModel model;
  final Map<String, dynamic> answersByKey;
  final Color textColor;
  /// Catalog override (tests / previews); defaults to the DI [UserProfileService] catalog.
  final WizCatalog? catalog;

  WizCatalog _catalog() {
    if (catalog != null) return catalog!;
    if (di.sl.isRegistered<UserProfileService>()) return di.sl<UserProfileService>().catalog;
    return const WizCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final snapshot = OnboardingProfileSnapshot(
      answers: answersByKey,
      catalog: _catalog(),
      languageCode: lang,
      dealsMultiplierOverride: model.dealsMultiplier,
    );
    final chips = snapshot.chips(model.summaryChipsFor(lang));
    final metadata = model.metadata;
    final sideText = TemplateText.textOf(context, metadata?.sideText);
    final highlightColor = wizHexColor(model.effectiveHighlightColor) ?? WizColors.amber;

    return OnboardingScrollFill(
      children: [
        OnboardingScreenHeader(
          model: model,
          textColor: textColor,
          titleStyle: WizType.titleXl.copyWith(height: 1.1),
          placeholders: snapshot.bodyPlaceholders,
          descriptionStyle: WizType.bodySecondary,
          descriptionGap: 0,
          bottomGap: 0,
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < chips.length; i++)
                FadeUp(
                  delay: WizMotion.chipStagger * i,
                  duration: WizMotion.replyEnter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: chips[i].background,
                      borderRadius: BorderRadius.circular(WizRadii.chip),
                    ),
                    child: Text(
                      chips[i].label,
                      style: WizType.captionStrong.copyWith(color: chips[i].foreground, height: 1.2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: metadata?.height ?? 200),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: _crossAxis(metadata?.sideTextAlignment),
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (sideText.isNotEmpty) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        sideText,
                        style: WizType.sectionTitle.copyWith(height: 1.3, color: textColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (model.visual != null)
                    VisualAssetWidget(
                      visualPath: model.visual!,
                      width: metadata?.width ?? 200,
                      height: metadata?.height ?? 200,
                    )
                  else
                    Icon(Icons.savings_outlined, size: 120, color: highlightColor),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Existing side-text alignment semantics mapped onto the row's cross axis.
  static CrossAxisAlignment _crossAxis(SideTextAlignment? alignment) {
    switch (alignment) {
      case SideTextAlignment.bottom:
        return CrossAxisAlignment.end;
      case SideTextAlignment.baseline:
        return CrossAxisAlignment.baseline;
      case SideTextAlignment.center:
        return CrossAxisAlignment.center;
      case SideTextAlignment.top:
      case null:
        return CrossAxisAlignment.start;
    }
  }
}
