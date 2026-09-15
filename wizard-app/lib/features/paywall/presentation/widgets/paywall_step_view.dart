import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';

/// Explainer step before the plans (intro / reminder): visual, H2, body, note, CTA.
class PaywallStepView extends StatelessWidget {
  const PaywallStepView({
    super.key,
    required this.step,
    required this.buttonLabel,
    required this.onContinue,
    this.busy = false,
  });

  final PaywallStepConfig step;
  final String buttonLabel;
  final VoidCallback? onContinue;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final title = TemplateText.textOf(context, step.title);
    final description = TemplateText.textOf(context, step.description);
    final note = TemplateText.textOf(context, step.noteText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: FadeUp(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PaywallStepVisual(path: step.visual),
                    const SizedBox(height: 20),
                    if (title.isNotEmpty)
                      Text(title, textAlign: TextAlign.center, style: WizType.titleXl),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          description,
                          textAlign: TextAlign.center,
                          style: WizType.bodySecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (note.isNotEmpty) ...[
          Text(
            note,
            textAlign: TextAlign.center,
            style: WizType.captionMedium.copyWith(color: WizColors.textSecondary),
          ),
          const SizedBox(height: 12),
        ],
        WizPrimaryButton(label: buttonLabel, onPressed: onContinue, loading: busy),
      ],
    );
  }
}

/// 220px art block: mascot on the yellow disc for PNGs, Lottie/SVG otherwise.
class PaywallStepVisual extends StatelessWidget {
  const PaywallStepVisual({super.key, required this.path, this.size = 180});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = path ?? '';
    if (p.isEmpty) return const SizedBox.shrink();
    final Widget child = p.toLowerCase().endsWith('.png')
        ? WizMascotOnDisc(discSize: size, mascotWidth: size)
        : VisualAssetWidget(visualPath: p, width: size, height: size);
    return SizedBox(
      height: size * 1.22,
      child: Align(alignment: Alignment.bottomCenter, child: child),
    );
  }
}
