import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/welcome_screen_config.dart';
import 'package:appwizard/features/onboarding/presentation/pages/welcome_screen_widget.dart';
import 'package:flutter/material.dart';

/// Loads `welcome_screen_config` from Remote Config and renders [WelcomeScreenWidget].
class WelcomeScreenPage extends StatefulWidget {
  const WelcomeScreenPage({super.key});

  @override
  State<WelcomeScreenPage> createState() => _WelcomeScreenPageState();
}

class _WelcomeScreenPageState extends State<WelcomeScreenPage> {
  WelcomeScreenConfig? _config;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      _config = di.sl<RemoteConfigService>().getWelcomeScreenConfig();
    } on Object catch (e, st) {
      di.sl<AppLogger>().e('Error loading welcome screen config', e, st);
    }
    _loading = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: WizColors.ink)),
      );
    }
    final config = _config;
    if (config == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: WizColors.appBackground),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: WizColors.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome screen configuration not available',
                      style: WizType.bodyMd,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return WelcomeScreenWidget(config: config);
  }
}
