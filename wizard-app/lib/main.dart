import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'l10n/app_localizations.dart';
import 'core/config/app_config.dart';
import 'core/di/injection_container.dart' as di;
import 'core/services/firebase_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'presentation/bloc/auth/auth_bloc.dart';

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
      create: (context) => AuthBloc(
        authService: di.sl<AuthService>(),
        logger: di.sl<AppLogger>(),
      ),
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: kDebugMode,
        
        // Router configuration
        routerConfig: AppRouter.router,
        
        // Localization configuration
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('en', ''), // English
          Locale('es', ''), // Spanish
        ],
        
        // Theme configuration
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system, // Automatically switch based on system settings
      ),
    );
  }
}
