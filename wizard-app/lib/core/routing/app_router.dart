import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/bloc/auth/auth_state.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/onboarding/onboarding_page.dart';
import '../../presentation/pages/onboarding/onboarding_screen.dart';

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
        builder: (context, state) {
          final authBloc = context.read<AuthBloc>();
          final authState = authBloc.state;

          // Show loading while checking auth
          if (authState is AuthInitial || authState is AuthLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If not authenticated, show onboarding
          if (authState is! AuthAuthenticated) {
            return const OnboardingPage();
          }

          // If authenticated, show home
          return const HomePage();
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingFlowPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}

