import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/presentation/bloc/auth/auth_bloc.dart';
import 'package:appwizard/presentation/bloc/auth/auth_event.dart';
import 'package:appwizard/presentation/bloc/auth/auth_state.dart';
import 'package:appwizard/l10n/app_localizations.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent to show global gradient
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is AuthAuthenticated) {
            // Navigate to home after successful authentication
            context.go('/');
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          if (state is AuthInitial) {
            return Scaffold(
              backgroundColor: Colors.transparent, // Transparent to show global gradient
              body: Center(child: CircularProgressIndicator(color: AppColors.backgroundDark)),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Modal-style sign-in card with glass effect
                GlassContainer(
                  blurSigma: 15.0,
                  color: Colors.black,
                  opacity: 0.3,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Title and close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.signIn,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                // Could navigate back or close modal
                                // For now, just a placeholder
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Sign in with Google button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    context.read<AuthBloc>().add(
                                          const SignInWithGoogleRequested(),
                                        );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google logo - using colored G icon
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'G',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  AppLocalizations.of(context)!.signInWithGoogle,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Sign in with Apple button (iOS only)
                        if (Platform.isIOS)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      context.read<AuthBloc>().add(
                                            const SignInWithAppleRequested(),
                                          );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A2A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.apple,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                    Text(
                                      AppLocalizations.of(context)!.signInWithApple,
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (Platform.isIOS) const SizedBox(height: 24),

                        // Terms and Privacy Policy
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                                children: [
                                  TextSpan(
                                    text: AppLocalizations.of(context)!.agreeToTerms(AppLocalizations.of(context)!.appTitle),
                                  ),
                                  const TextSpan(
                                    text: " ",
                                  ),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () {
                                        // TODO: Navigate to Terms and Conditions
                                      },
                                      child: Text(
                                        AppLocalizations.of(context)!.termsAndConditions,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[300],
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.grey[300],
                                          fontWeight: FontWeight.w500,
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
                                        // TODO: Navigate to Privacy Policy
                                      },
                                      child: Text(
                                        AppLocalizations.of(context)!.privacyPolicy,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[300],
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.grey[300],
                                          fontWeight: FontWeight.w500,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
