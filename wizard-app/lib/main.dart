import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'l10n/app_localizations.dart';
import 'core/di/injection_container.dart' as di;
import 'presentation/pages/splash/splash_page.dart';
import 'presentation/bloc/splash/splash_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection
  await di.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SplashBloc()),
        // Add other BLoCs here as needed
      ],
      child: MaterialApp(
        title: 'Bargain Wiz',
        debugShowCheckedModeBanner: false,
        
        // Localization configuration
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('en', ''), // English
          Locale('es', ''), // Spanish
        ],
        
        // Theme configuration
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        
        // Start with splash screen
        home: const SplashPage(),
      ),
    );
  }
}
