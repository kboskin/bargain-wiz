import 'package:flutter/material.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import 'welcome_screen_widget.dart';

/// Page that loads and displays the welcome screen from remote config
class WelcomeScreenPage extends StatefulWidget {
  const WelcomeScreenPage({super.key});

  @override
  State<WelcomeScreenPage> createState() => _WelcomeScreenPageState();
}

class _WelcomeScreenPageState extends State<WelcomeScreenPage> {
  bool _isLoading = true;
  dynamic _config;

  @override
  void initState() {
    super.initState();
    _loadWelcomeScreenConfig();
  }

  Future<void> _loadWelcomeScreenConfig() async {
    try {
      final remoteConfigService = di.sl<RemoteConfigService>();
      final config = remoteConfigService.getWelcomeScreenConfig();

      if (mounted) {
        setState(() {
          _config = config;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_config == null) {
      // Fallback UI if config is not available
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.backgroundDark.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome screen configuration not available',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.backgroundDark.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return WelcomeScreenWidget(config: _config);
  }
}

