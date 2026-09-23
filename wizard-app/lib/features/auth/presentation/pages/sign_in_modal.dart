import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_sheet.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_event.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_state.dart';
import 'package:appwizard/features/auth/presentation/widgets/auth_button.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// Sign-in bottom sheet (README §10): frosted 90%, "Sign in" Outfit 26, Google (outlined) /
/// Apple (ink, iOS only) 54h buttons, legal line with Terms / Privacy links.
///
/// Works as a plain `showModalBottomSheet` body (transparent background) or via [show].
/// Needs an [AuthBloc] above it (provided at the app root).
class SignInModal extends StatelessWidget {
  const SignInModal({super.key});

  static Future<void> show(BuildContext context) =>
      WizSheet.show<void>(context, builder: (_) => const SignInModal());

  /// Routes that render the main shell; signing in there just closes the sheet.
  static const Set<String> _shellPaths = {
    AppRoutes.home,
    AppRoutes.main,
    AppRoutes.lines,
    AppRoutes.history,
    AppRoutes.profile,
  };

  static Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onAuthenticated(BuildContext context) {
    GoRouter? router;
    String? path;
    try {
      router = GoRouter.of(context);
      path = router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      // Rendered outside the router (tests): just pop.
    }
    Navigator.of(context).pop();
    if (router != null && path != null && !_shellPaths.contains(path)) {
      router.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rc = di.sl<RemoteConfigService>();
    final showApple = !kIsWeb && Platform.isIOS;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) _onAuthenticated(context);
      },
      builder: (context, state) {
        return WizSheet(
          color: WizColors.frostedDialog,
          title: l10n.signIn,
          titleStyle: WizType.titleMd,
          onClose: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Your deals and plan follow you across devices.', style: WizType.bodyMd),
              const SizedBox(height: 18),
              GoogleSignInButton(
                loading: state is AuthLoading,
                onTap: state is AuthInitial
                    ? null
                    : () => context.read<AuthBloc>().add(const SignInWithGoogleRequested()),
              ),
              if (showApple) ...[
                const SizedBox(height: WizSpacing.stack),
                AppleSignInButton(
                  loading: state is AuthLoading,
                  onTap: state is AuthInitial
                      ? null
                      : () => context.read<AuthBloc>().add(const SignInWithAppleRequested()),
                ),
              ],
              if (state is AuthError) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.signInError,
                  textAlign: TextAlign.center,
                  style: WizType.caption.copyWith(color: WizColors.errorText),
                ),
              ],
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: WizType.footnote,
                  children: [
                    TextSpan(text: '${l10n.agreeToTerms(l10n.appTitle)} '),
                    _link(l10n.termsAndConditions, () => _launchUrl(rc.getTermsOfUseUrl())),
                    TextSpan(text: ' ${l10n.and.trim()} '),
                    _link(l10n.privacyPolicy, () => _launchUrl(rc.getPrivacyPolicyUrl())),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  static InlineSpan _link(String text, VoidCallback onTap) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            text,
            style: WizType.footnote.copyWith(
              color: WizColors.textSecondary,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: WizColors.textSecondary,
            ),
          ),
        ),
      );
}
