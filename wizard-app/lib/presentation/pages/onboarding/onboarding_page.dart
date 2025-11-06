import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../auth/sign_in_modal.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent to show global gradient
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // App preview/phone mockup placeholder with glass effect
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: GlassContainer(
                blurSigma: 10.0,
                color: Colors.white,
                opacity: 0.2,
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 500,
                  child: Center(
                    child: Icon(
                      Icons.shopping_bag,
                      size: 80,
                      color: AppColors.backgroundDark.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Headline with styled text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppColors.backgroundDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                  children: [
                    const TextSpan(text: 'Be a '),
                    TextSpan(
                      text: 'Deal God',
                      style: TextStyle(
                        color: AppColors.backgroundDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 36,
                        shadows: [
                          Shadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Subheadline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.backgroundDark.withValues(alpha: 0.9),
                        height: 1.5,
                        fontSize: 18,
                      ),
                  children: [
                    const TextSpan(text: 'Get the best '),
                    TextSpan(
                      text: 'bargain',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const TextSpan(text: ' deals.\nNever overpay again.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to onboarding flow
                    context.push('/onboarding');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Sign in link
            TextButton(
              onPressed: () {
                _showSignInModal(context);
              },
                    child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: AppColors.backgroundDark,
                    fontSize: 14,
                  ),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'Sign in',
                      style: TextStyle(
                        color: AppColors.backgroundDark,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.backgroundDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  void _showSignInModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SignInModal(),
    );
  }
}

