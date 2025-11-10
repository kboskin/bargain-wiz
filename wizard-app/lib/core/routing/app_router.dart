import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/bloc/auth/auth_state.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/onboarding/onboarding_screen.dart';
import '../../presentation/pages/onboarding/welcome_screen_page.dart';

/// App router configuration
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final authBloc = context.read<AuthBloc>();
      final authState = authBloc.state;
      final isGoingToHome = state.matchedLocation == '/';

      // If authenticated and trying to go to home, allow it
      if (authState is AuthAuthenticated) {
        return null;
      }

      // If not authenticated and trying to go to home, show onboarding
      if (authState is AuthUnauthenticated && isGoingToHome) {
        return null; // Show onboarding page
      }

      // If still checking auth, allow navigation but show loading
      if (authState is AuthInitial || authState is AuthLoading) {
        return null; // Let the route handle loading state
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                // Show loading while checking auth
                if (authState is AuthInitial || authState is AuthLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // If not authenticated, show welcome screen
                if (authState is! AuthAuthenticated) {
                  return const WelcomeScreenPage();
                }

                // If authenticated, show home
                return const HomePage();
              },
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // When navigating away, slide out to the left
              const curve = Curves.linear;
              
              var slideOutAnimation = Tween(
                begin: Offset.zero,
                end: const Offset(-1.0, 0.0),
              ).animate(
                CurvedAnimation(
                  parent: secondaryAnimation,
                  curve: curve,
                ),
              );

              return SlideTransition(
                position: slideOutAnimation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const OnboardingFlowPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Push transition: new screen slides in from right
              const curve = Curves.linear;

              // Incoming screen: slides from right (1.0) to center (0.0)
              var slideInAnimation = Tween(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: curve,
                ),
              );

              return SlideTransition(
                position: slideInAnimation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}

