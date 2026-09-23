import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_event.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_state.dart';
import 'package:appwizard/features/auth/presentation/widgets/auth_button.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
                        GoogleSignInButton(
                          label: googleLabel,
                          loading: isLoading,
                          onTap: () => context.read<AuthBloc>().add(const SignInWithGoogleRequested()),
                        ),
                      if (showGoogle && showApple) const SizedBox(height: 12),
                      if (showApple)
                        AppleSignInButton(
                          label: appleLabel,
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
