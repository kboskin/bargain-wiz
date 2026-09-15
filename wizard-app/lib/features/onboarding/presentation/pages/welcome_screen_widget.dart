import 'dart:math' as math;

import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/auth/presentation/pages/sign_in_modal.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/welcome_screen_config.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/welcome_hero_video.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Welcome / landing screen (README §1): brand row, H1 with highlight words,
/// subtitle, frosted hero with yellow disc + mascot, primary CTA and sign-in link.
class WelcomeScreenWidget extends StatelessWidget {
  const WelcomeScreenWidget({required this.config, super.key});

  final WelcomeScreenConfig config;

  static const double _mascotAspect = 678 / 558;

  @override
  Widget build(BuildContext context) {
    final textColor = wizHexColor(config.textColor) ?? WizColors.ink;
    final highlightColor = wizHexColor(config.highlightColor) ?? WizColors.amber;
    final title = TemplateText.textOf(context, config.title, fallback: 'Get the Best Deals');
    final description = TemplateText.textOf(context, config.description);
    final cta = TemplateText.textOf(context, config.primaryButtonText, fallback: 'Get Started');
    final secondary = config.secondaryAction;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: WizColors.appBackground),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 11, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: WizBrandRow()),
                const SizedBox(height: 28),
                HighlightedText(
                  title,
                  style: WizType.welcomeTitle.copyWith(color: textColor),
                  highlights: config.highlightWords?.title,
                  defaultHighlightColor: highlightColor,
                  boldColor: textColor,
                  textAlign: TextAlign.center,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  HighlightedText(
                    description,
                    style: WizType.bodyLg,
                    highlights: config.highlightWords?.description,
                    defaultHighlightColor: highlightColor,
                    highlightWeight: FontWeight.w600,
                    boldColor: textColor,
                    textAlign: TextAlign.center,
                  ),
                ],
                Expanded(child: _Hero(visual: config.visual, video: config.video)),
                WizPrimaryButton(label: cta, onPressed: () => context.push(AppRoutes.onboarding)),
                if (secondary != null && secondary.type == 'sign_in') ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showSignInModal(context),
                    child: Text.rich(
                      TextSpan(
                        style: WizType.bodySm,
                        children: [
                          TextSpan(text: TemplateText.textOf(context, secondary.prefixText)),
                          TextSpan(
                            text: TemplateText.textOf(context, secondary.text, fallback: 'Sign in'),
                            style: WizType.bodySmBold.copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: WizColors.ink,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSignInModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SignInModal(),
    );
  }
}

/// Flex-fill hero: radius 28, white 55%, border white 95%, strong shadow. Shows the
/// marketing [video] when configured, otherwise the 230px yellow disc + mascot poster.
class _Hero extends StatelessWidget {
  const _Hero({this.visual, this.video});

  final String? visual;
  final WelcomeVideoConfig? video;

  @override
  Widget build(BuildContext context) {
    final poster = _MascotPoster(visual: visual);
    final v = video;
    return Container(
      margin: const EdgeInsets.only(top: 26, bottom: 22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WizColors.frostedLight,
        borderRadius: BorderRadius.circular(WizRadii.cardHero),
        border: Border.all(color: WizColors.frostedBorder),
        boxShadow: WizShadows.cardStrong,
      ),
      child: v != null && v.isEnabled ? WelcomeHeroVideo(config: v, poster: poster) : poster,
    );
  }
}

/// Default hero content: 230px yellow disc at top 22 and the mascot (270 wide)
/// bottom-aligned, or the configured [visual].
class _MascotPoster extends StatelessWidget {
  const _MascotPoster({this.visual});

  final String? visual;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 500.0;
          final disc = math.min(230.0, h * 0.55);
          final mascotWidth = math.min(270.0, (h - 22) * 0.92 / WelcomeScreenWidget._mascotAspect);
          final mascotHeight = mascotWidth * WelcomeScreenWidget._mascotAspect;
          // Keep the disc behind the wizard's hat on tall screens: anchor it to the
          // mascot instead of the container top (top 22 only when the hero is ~500px).
          final discBottom = math.max(0.0, math.min(mascotHeight * 0.62, h - 22 - disc));
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: discBottom,
                child: Container(
                  width: disc,
                  height: disc,
                  decoration: BoxDecoration(
                    color: WizColors.yellow.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(bottom: 0, child: _mascot(mascotWidth)),
            ],
          );
        },
      );

  Widget _mascot(double width) {
    final path = visual;
    if (path == null || path.isEmpty || path.endsWith(WizMascot.asset.split('/').last)) {
      return WizMascot(width: width);
    }
    return VisualAssetWidget(visualPath: path, width: width, height: width * WelcomeScreenWidget._mascotAspect);
  }
}
