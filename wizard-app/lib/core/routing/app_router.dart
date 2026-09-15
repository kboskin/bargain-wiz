import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dartz/dartz.dart';

import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_state.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/express_dealmaker_page.dart';
import 'package:appwizard/features/feedback/presentation/pages/feedback_form_page.dart';
import 'package:appwizard/features/main_shell/presentation/pages/main_shell_page.dart';
import 'package:appwizard/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:appwizard/features/onboarding/presentation/pages/welcome_screen_page.dart';
import 'package:appwizard/features/paywall/domain/paywall_args.dart';
import 'package:appwizard/features/paywall/presentation/pages/paywall_page.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/pages/pro_deal_closer_page.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/core/error/failures.dart';
import 'app_routes.dart';

/// App router configuration
class AppRouter {
  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is AuthInitial || authState is AuthLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (authState is AuthAuthenticated) {
                return const MainShellPage();
              }
              // Not authenticated: go to the shell once onboarding has been completed,
              // otherwise show the welcome screen.
              final repo = di.sl<OnboardingRepository>();
              return FutureBuilder<Either<Failure, bool>>(
                future: repo.isOnboardingCompleted(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final completed = snapshot.data!.fold((_) => false, (v) => v);
                  return completed ? const MainShellPage() : const WelcomeScreenPage();
                },
              );
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
            position: Tween(begin: Offset.zero, end: const Offset(-1.0, 0.0))
                .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.linear)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingFlowPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.linear)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: AppRoutes.main,
        name: AppRoutes.mainName,
        builder: (context, state) => const MainShellPage(),
      ),
      GoRoute(
        path: AppRoutes.lines,
        name: AppRoutes.linesName,
        builder: (context, state) => const MainShellPage(initialTab: MainTab.lines),
      ),
      GoRoute(
        path: AppRoutes.history,
        name: AppRoutes.historyName,
        builder: (context, state) => const MainShellPage(initialTab: MainTab.history),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: AppRoutes.profileName,
        builder: (context, state) => const MainShellPage(initialTab: MainTab.profile),
      ),
      GoRoute(
        path: AppRoutes.express,
        name: AppRoutes.expressName,
        pageBuilder: (context, state) => _slideUp(
          state,
          ExpressDealmakerPage(
            args: state.extra is ExpressDealmakerArgs ? state.extra as ExpressDealmakerArgs : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.pro,
        name: AppRoutes.proName,
        pageBuilder: (context, state) => _slideUp(
          state,
          ProDealCloserPage(
            args: state.extra is ProDealCloserArgs ? state.extra as ProDealCloserArgs : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.startWithText,
        name: AppRoutes.startWithTextName,
        redirect: (context, state) => AppRoutes.pro,
      ),
      GoRoute(
        path: AppRoutes.paywall,
        name: AppRoutes.paywallName,
        pageBuilder: (context, state) => _slideUp(
          state,
          BlocProvider<SubscriptionBloc>(
            create: (_) => di.sl<SubscriptionBloc>(),
            child: PaywallPage(
              args: state.extra is PaywallArgs ? state.extra as PaywallArgs : const PaywallArgs(),
            ),
          ),
          fullscreenDialog: true,
        ),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        name: AppRoutes.feedbackName,
        builder: (context, state) => const FeedbackFormPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );

  static CustomTransitionPage<T> _slideUp<T>(
    GoRouterState state,
    Widget child, {
    bool fullscreenDialog = false,
  }) =>
      CustomTransitionPage<T>(
        key: state.pageKey,
        fullscreenDialog: fullscreenDialog,
        child: child,
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );
}
