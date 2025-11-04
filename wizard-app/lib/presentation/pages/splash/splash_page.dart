import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/splash/splash_bloc.dart';
import '../../bloc/splash/splash_event.dart';
import '../../bloc/splash/splash_state.dart';
import '../../../core/utils/splash_config.dart';
import '../home/home_page.dart';

/// Splash screen page that shows during app initialization
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    // Trigger splash completion after initialization
    _initializeApp();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    // Minimum splash duration to ensure users see the splash screen
    final minDuration = Future.delayed(
      Duration(milliseconds: SplashConfig.minSplashDurationMs),
    );

    // Simulate initialization tasks (e.g., loading user preferences, checking auth)
    // In a real app, you might want to:
    // - Check if user is logged in
    // - Load cached data
    // - Initialize services
    // - Check for app updates
    // - Initialize analytics
    final initTasks = Future.wait([
      // Add your initialization tasks here
      // Example: _loadUserPreferences(),
      // Example: _checkAuthentication(),
    ]);

    // Wait for both minimum duration and initialization tasks
    await Future.wait([minDuration, initTasks]);

    // Dispatch event to complete splash
    if (mounted) {
      context.read<SplashBloc>().add(SplashInitialized());
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashBloc, SplashState>(
      listener: (context, state) {
        if (state is SplashCompleted) {
          // Navigate to home page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo or icon
                Icon(
                  Icons.shopping_bag,
                  size: 100,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(height: 24),
                // App name
                Text(
                  'Bargain Wiz',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 48),
                // Loading indicator
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

