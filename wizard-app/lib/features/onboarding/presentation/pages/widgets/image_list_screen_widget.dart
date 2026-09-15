import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';

/// `image_list` template (retired from the default order, kept as a template):
/// frosted rows with a 64px thumb + Outfit 16/600 title + Figtree 13 subtitle
/// (`metadata.rows[i].title/subtitle`), or plain full-width images when no rows.
class ImageListScreenWidget extends StatelessWidget {
  const ImageListScreenWidget({required this.model, super.key, this.textColor = WizColors.ink});

  final ImageListScreenModel model;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final rows = model.rows;
    final spacing = model.metadata?.imageSpacing ?? WizSpacing.stack;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingScreenHeader(model: model, textColor: textColor, bottomGap: 18),
        Expanded(
          child: ListView.separated(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: model.images.length,
            separatorBuilder: (_, __) => SizedBox(height: spacing),
            itemBuilder: (context, i) {
              final row = i < rows.length ? rows[i] : null;
              final title = TemplateText.textOf(context, row?['title']);
              final subtitle = TemplateText.textOf(context, row?['subtitle'] ?? row?['description']);
              return FadeUp(
                delay: WizMotion.listStagger * i,
                child: FrostedSurface(
                  radius: WizRadii.card,
                  shadow: WizShadows.cardSoft,
                  padding: const EdgeInsets.all(12),
                  child: title.isEmpty && subtitle.isEmpty
                      ? VisualAssetWidget(
                          visualPath: model.images[i],
                          width: model.metadata?.imageWidth ?? double.infinity,
                          height: model.metadata?.imageHeight ?? 200,
                        )
                      : Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: VisualAssetWidget(
                                visualPath: model.images[i],
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (title.isNotEmpty) Text(title, style: WizType.optionLabel.copyWith(color: textColor)),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(subtitle, style: WizType.caption.copyWith(height: 1.35)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
