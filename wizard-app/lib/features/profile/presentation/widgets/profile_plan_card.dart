import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';

/// Ink plan card with the decorative purple disc; "CURRENT PLAN" · name · sub · yellow CTA.
class ProfilePlanCard extends StatelessWidget {
  const ProfilePlanCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
    this.label = 'CURRENT PLAN',
  });

  final String name;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback? onCta;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: WizColors.ink,
          borderRadius: BorderRadius.circular(WizRadii.cardXl),
          boxShadow: const [
            BoxShadow(color: Color(0x3814121B), blurRadius: 30, offset: Offset(0, 12)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Opacity(
                opacity: 0.55,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(color: WizColors.purple, shape: BoxShape.circle),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: WizType.label.copyWith(
                            fontSize: 11,
                            letterSpacing: 1.1,
                            color: WizColors.borderStrong,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(name, style: WizType.titleXs.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: WizType.caption.copyWith(color: WizColors.borderStrong)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ProfileSmallPill(label: ctaLabel, onTap: onCta),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 36h yellow pill, Figtree 13/600 ink (plan card "Manage" / "Upgrade").
class ProfileSmallPill extends StatelessWidget {
  const ProfileSmallPill({
    super.key,
    required this.label,
    required this.onTap,
    this.color = WizColors.yellow,
    this.textColor = WizColors.ink,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => WizPressable(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(label, style: WizType.captionStrong.copyWith(color: textColor, height: 1)),
          ),
        ),
      );
}
