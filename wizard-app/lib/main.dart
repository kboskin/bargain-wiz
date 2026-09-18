import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:appwizard/core/app/app_bootstrap.dart';
import 'package:appwizard/core/app/app_splash.dart';
import 'package:appwizard/core/config/app_config.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_router.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/app_theme.dart';
import 'package:appwizard/core/widgets/pastel_gradient_background.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// Paints the first frame straight away and initializes behind the splash (see
/// [AppBootstrap]): Firebase, the dependency container and the bundled Remote Config
/// defaults. The Remote Config fetch, anonymous sign-in and profile sync run in the
/// background, so nothing on the network can delay the launch.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BargainWizApp());
}

class BargainWizApp extends StatefulWidget {
  const BargainWizApp({super.key});

  @override
  State<BargainWizApp> createState() => _BargainWizAppState();
}

class _BargainWizAppState extends State<BargainWizApp> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_boot()); // waits for the splash frame itself, then initializes
  }

  Future<void> _boot() async {
    final error = await AppBootstrap.run();
    if (!mounted) return;
    setState(() {
      _ready = error == null;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const MyApp();
    return BootSplash(message: _error, onRetry: _error == null ? null : () => unawaited(_boot()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<AuthBloc>(),
      // Remote values arrive after the first frame; this rebuilds the config-driven widgets
      // (gradient, template copy) once they are activated.
      child: ListenableBuilder(
        listenable: di.sl<RemoteConfigService>(),
        builder: (context, _) => PastelGradientBackground(
          // No blur: a BackdropFilter over the gradient repaints every frame for no visible
          // difference, and it was the biggest cost in the first build.
          child: MaterialApp.router(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: kDebugMode,

            // Router configuration
            routerConfig: di.sl<AppRouter>().router,

            // Localization configuration
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [
              Locale('en', ''), // English
              Locale('es', ''), // Spanish
            ],

            // Theme configuration
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light, // Design is light-only (dark palette not designed yet)
          ),
        ),
      ),
    );
  }
}
