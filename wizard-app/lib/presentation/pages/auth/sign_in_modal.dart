import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/presentation/bloc/auth/auth_bloc.dart';
import 'package:appwizard/presentation/bloc/auth/auth_event.dart';
import 'package:appwizard/presentation/bloc/auth/auth_state.dart';
import 'package:appwizard/l10n/app_localizations.dart';

class SignInModal extends StatelessWidget {
  const SignInModal({super.key});

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) {
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfigService = di.sl<RemoteConfigService>();
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is AuthAuthenticated) {
          // Close modal and navigate to home
          Navigator.of(context).pop();
          context.go('/');
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        if (state is AuthInitial) {
          return GlassContainer(
            blurSigma: 20.0,
            color: Colors.white,
            opacity: 0.25,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          );
        }

        return GlassContainer(
          blurSigma: 20.0,
          color: Colors.white,
          opacity: 0.25,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)!.signIn,
                    style: AppTextStyles.headlineMediumDark.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 24,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(40, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Sign in with Google button
              _buildSignInButton(
                context: context,
                isLoading: isLoading,
                onPressed: () {
                  context.read<AuthBloc>().add(
                        const SignInWithGoogleRequested(),
                      );
                },
                icon: _buildGoogleIcon(),
                label: AppLocalizations.of(context)!.signInWithGoogle,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.backgroundDark,
              ),
              const SizedBox(height: 16),

              // Sign in with Apple button (iOS only)
              if (Platform.isIOS) ...[
                _buildSignInButton(
                  context: context,
                  isLoading: isLoading,
                  onPressed: () {
                    context.read<AuthBloc>().add(
                          const SignInWithAppleRequested(),
                        );
                  },
                  icon: const Icon(
                    Icons.apple_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                  label: AppLocalizations.of(context)!.signInWithApple,
                  backgroundColor: AppColors.backgroundDark,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(height: 24),
              ],

              // Terms and Privacy Policy
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.visible,
                    text: TextSpan(
                      style: AppTextStyles.bodySmallDark.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: AppLocalizations.of(context)!.agreeToTerms(AppLocalizations.of(context)!.appTitle),
                        ),
                        const TextSpan(text: ' '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                              final termsUrl = remoteConfigService.getTermsOfUseUrl();
                              _launchUrl(termsUrl);
                            },
                            child: Text(
                              AppLocalizations.of(context)!.termsAndConditions,
                              style: AppTextStyles.bodySmallDark.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white.withValues(alpha: 0.95),
                                decorationThickness: 1.5,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: AppLocalizations.of(context)!.and,
                        ),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                              final privacyUrl = remoteConfigService.getPrivacyPolicyUrl();
                              _launchUrl(privacyUrl);
                            },
                            child: Text(
                              AppLocalizations.of(context)!.privacyPolicy,
                              style: AppTextStyles.bodySmallDark.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white.withValues(alpha: 0.95),
                                decorationThickness: 1.5,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build a styled sign-in button
  Widget _buildSignInButton({
    required BuildContext context,
    required bool isLoading,
    required VoidCallback onPressed,
    required Widget icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.pressed)) {
                  return foregroundColor.withValues(alpha: 0.1);
                }
                if (states.contains(WidgetState.hovered)) {
                  return foregroundColor.withValues(alpha: 0.05);
                }
                return null;
              },
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
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
                      style: AppTextStyles.labelLarge.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Build Google icon using FontAwesome Google logo
  Widget _buildGoogleIcon() {
    return const FaIcon(
      FontAwesomeIcons.google,
      size: 24,
      color: Color(0xFF4285F4), // Google blue
    );
  }
}

