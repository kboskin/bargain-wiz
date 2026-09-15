import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/core/config/app_config.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/routing/app_router.dart';
import 'package:appwizard/core/theme/app_theme.dart';
import 'package:appwizard/core/widgets/pastel_gradient_background.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Initialize dependency injection
  await di.init();
  
  // Initialize Remote Config Service (loads configs on startup)
  await di.sl<RemoteConfigService>().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<AuthBloc>(),
      child: PastelGradientBackground(
        blurSigma: 2.0, // Subtle blur for glass effect
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
    );
  }
}
