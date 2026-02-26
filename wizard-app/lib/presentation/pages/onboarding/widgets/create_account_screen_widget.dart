import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/presentation/bloc/auth/auth_bloc.dart';
import 'package:appwizard/presentation/bloc/auth/auth_event.dart';
import 'package:appwizard/presentation/bloc/auth/auth_state.dart';

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
    default:
      return 'web';
  }
}

/// True if [platforms] is null/empty (show on all) or contains [_currentPlatform].
bool _showOnPlatform(List<String>? platforms) {
  if (platforms == null || platforms.isEmpty) return true;
  return platforms.map((e) => e.toLowerCase()).contains(_currentPlatform);
}

/// Resolve button label from config (multilocale or string) with fallback.
String _getButtonLabel(BuildContext context, dynamic source, String fallback) {
  if (source == null) return fallback;
  if (source is MultilocaleText) return source.get(context);
  if (source is String) return source.isNotEmpty ? source : fallback;
  return fallback;
}

/// Create-account screen: Google/Apple sign-in buttons and Continue (skip).
/// Labels and which platforms show each button come from remote config.
class CreateAccountScreenWidget extends StatelessWidget {
  const CreateAccountScreenWidget({
    super.key,
    required this.model,
    required this.onContinue,
  });

  final CreateAccountScreenModel model;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        if (current is AuthError) return true;
        if (previous is AuthLoading && current is AuthAuthenticated) return true;
        return false;
      },
      listener: (context, state) {
        if (state is AuthError) {
          _showSignInErrorDialog(context);
        } else if (state is AuthAuthenticated) {
          onContinue();
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final titleText = model.title.get(context);
        final descriptionText = model.description?.get(context) ?? '';
        final googleLabel = _getButtonLabel(context, model.googleButtonLabel, 'Google');
        final appleLabel = _getButtonLabel(context, model.appleButtonLabel, 'Apple');
        final showGoogle = _showOnPlatform(model.googlePlatforms);
        final showApple = _showOnPlatform(model.applePlatforms);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppColors.backgroundDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                      if (descriptionText.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          descriptionText,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.backgroundDark.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else
                        const SizedBox(height: 24),
                      if (showGoogle) ...[
                        _StyledSignInButton(
                          icon: _GoogleGIcon(size: 24),
                          label: googleLabel,
                          isLoading: isLoading,
                          onPressed: () {
                            context.read<AuthBloc>().add(const SignInWithGoogleRequested());
                          },
                        ),
                        if (showApple) const SizedBox(height: 16),
                      ],
                      if (showApple)
                        _AppleSignInButton(
                          label: appleLabel,
                          isLoading: isLoading,
                          onPressed: () {
                            context.read<AuthBloc>().add(const SignInWithAppleRequested());
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSignInErrorDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.error),
        content: Text(l10n.signInError),
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        _kGoogleGSvg,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Outlined button with logo + text matching app style (rounded, border, dark text).
class _StyledSignInButton extends StatelessWidget {
  const _StyledSignInButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.buttonText.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Sign in with Apple button – black background, white icon/text (Apple HIG style).
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  static const Color _appleBlack = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _appleBlack,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.apple, size: 24, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.buttonText.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
