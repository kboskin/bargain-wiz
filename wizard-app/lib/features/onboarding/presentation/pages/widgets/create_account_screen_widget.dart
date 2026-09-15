import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_event.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_state.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Current platform identifier for remote config (e.g. "android", "ios", "web").
String get _currentPlatform {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

/// True if [platforms] is null/empty (use [fallback]) or contains the current platform.
bool _showOnPlatform(List<String>? platforms, {required bool fallback}) {
  if (platforms == null || platforms.isEmpty) return fallback;
  return platforms.map((e) => e.toLowerCase()).contains(_currentPlatform);
}

/// `create_account` template ("Lock in your wizard"): mascot, title, description,
/// Continue with Google / Apple. The shell renders the "Skip for now" CTA.
class CreateAccountScreenWidget extends StatelessWidget {
  const CreateAccountScreenWidget({
    required this.model,
    required this.onContinue,
    super.key,
    this.textColor = WizColors.ink,
  });

  final CreateAccountScreenModel model;
  final VoidCallback onContinue;
  final Color textColor;

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current is AuthError || (previous is AuthLoading && current is AuthAuthenticated),
        listener: (context, state) {
          if (state is AuthError) {
            _showSignInErrorDialog(context);
          } else if (state is AuthAuthenticated) {
            onContinue();
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final title = TemplateText.textOf(context, model.title);
          final description = TemplateText.textOf(context, model.description);
          final googleLabel = TemplateText.textOf(context, model.googleButtonLabel, fallback: 'Continue with Google');
          final appleLabel = TemplateText.textOf(context, model.appleButtonLabel, fallback: 'Continue with Apple');
          final showGoogle = _showOnPlatform(model.googlePlatforms, fallback: true);
          final isApplePlatform =
              defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
          final showApple = _showOnPlatform(model.applePlatforms, fallback: isApplePlatform);
          final highlightColor = wizHexColor(model.effectiveHighlightColor);

          return OnboardingScrollFill(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _visual()),
                      const SizedBox(height: 20),
                      HighlightedText(
                        title,
                        style: WizType.titleXl.copyWith(color: textColor),
                        highlights: model.titleHighlights,
                        defaultHighlightColor: highlightColor,
                        boldColor: textColor,
                        textAlign: TextAlign.center,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        HighlightedText(
                          description,
                          style: WizType.bodySecondary,
                          highlights: model.descriptionHighlights,
                          defaultHighlightColor: highlightColor,
                          highlightWeight: FontWeight.w600,
                          boldColor: textColor,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (showGoogle)
                        _AuthButton(
                          label: googleLabel,
                          leading: const _GoogleGIcon(size: 20),
                          fill: Colors.white,
                          borderColor: WizColors.border,
                          textColor: WizColors.ink,
                          loading: isLoading,
                          onTap: () => context.read<AuthBloc>().add(const SignInWithGoogleRequested()),
                        ),
                      if (showGoogle && showApple) const SizedBox(height: 12),
                      if (showApple)
                        _AuthButton(
                          label: appleLabel,
                          leading: const Icon(Icons.apple, size: 20, color: Colors.white),
                          fill: WizColors.ink,
                          textColor: Colors.white,
                          loading: isLoading,
                          onTap: () => context.read<AuthBloc>().add(const SignInWithAppleRequested()),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget _visual() {
    final path = model.visual;
    if (path == null || path.isEmpty || path.endsWith(WizMascot.asset.split('/').last)) {
      return const WizMascot(width: 120);
    }
    return VisualAssetWidget(visualPath: path, width: 120, height: 120);
  }

  void _showSignInErrorDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.error ?? 'Error'),
        content: Text(l10n?.signInError ?? 'Sign-in failed. Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// 54h, radius 27 sign-in button (white + border for Google, ink for Apple), Figtree 16/600.
class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.leading,
    required this.fill,
    required this.textColor,
    required this.onTap,
    this.borderColor,
    this.loading = false,
  });

  final String label;
  final Widget leading;
  final Color fill;
  final Color? borderColor;
  final Color textColor;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => WizPressable(
        onTap: loading ? null : onTap,
        child: Opacity(
          opacity: loading ? 0.7 : 1,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(27),
              border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.5),
            ),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      leading,
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: WizType.bodyFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
}

/// Embedded Google "G" logo SVG – colored, no background.
const String _kGoogleGSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
</svg>
''';

class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon({this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: SvgPicture.string(_kGoogleGSvg, width: size, height: size, fit: BoxFit.contain),
      );
}
