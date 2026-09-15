import 'package:flutter/material.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_sheet.dart';
import 'package:appwizard/features/home/data/models/refer_config.dart';
import 'package:appwizard/features/home/presentation/utils/share_helper.dart';
import 'package:appwizard/features/home/presentation/widgets/highlighted_text.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// Dark "Invite friends & earn" sheet (README §10): ink, radius 32, padding 12 24 44,
/// Outfit 26 title with teal highlight, 3 ✓ benefits, white "Share invite link" CTA.
class ReferSheet extends StatelessWidget {
  const ReferSheet({super.key, this.config});

  final ReferConfig? config;

  static Future<void> show(BuildContext context) {
    final config = di.sl<RemoteConfigService>().getReferConfig();
    return WizSheet.show<void>(context, builder: (_) => ReferSheet(config: config));
  }

  static const Color _benefitColor = Color(0xFFE9E5F0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _nonEmpty(config?.getTitle(context)) ?? l10n.referModalTitle;
    final configured = config?.getBenefits(context).where((b) => b.trim().isNotEmpty).toList() ?? const [];
    final benefits = configured.isNotEmpty
        ? configured
        : [l10n.referBenefit1, l10n.referBenefit2, l10n.referBenefit3];
    final cta = _nonEmpty(config?.getCtaButtonText(context)) ?? l10n.referShareInvite;
    final highlightColor =
        HighlightedText.parseHexColor(config?.highlightColor) ?? WizColors.teal;

    return WizSheet(
      color: WizColors.ink,
      handleColor: Colors.white.withValues(alpha: 0.25),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          HighlightedText(
            title,
            style: WizType.titleMd.copyWith(color: Colors.white, height: 1.1),
            highlights: config?.highlightWords,
            section: 'title',
            defaultHighlightColor: highlightColor,
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < benefits.length; i++) ...[
            _Benefit(
              text: benefits[i],
              highlights: config?.highlightWords,
              highlightColor: highlightColor,
            ),
            if (i < benefits.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 22),
          WizPrimaryButton(
            label: cta,
            color: Colors.white,
            textColor: WizColors.ink,
            onPressed: () {
              // Read the localized share copy while the sheet is still mounted, then close it.
              final navigator = Navigator.of(context);
              ShareHelper.shareRefer(context, config);
              navigator.pop();
            },
          ),
        ],
      ),
    );
  }

  static String? _nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text, this.highlights, required this.highlightColor});

  final String text;
  final dynamic highlights;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✓',
            style: WizType.bodyMd.copyWith(color: WizColors.teal, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: HighlightedText(
              text,
              style: WizType.bodyMd.copyWith(color: ReferSheet._benefitColor),
              highlights: highlights,
              section: 'description',
              defaultHighlightColor: Colors.white,
            ),
          ),
        ],
      );
}
