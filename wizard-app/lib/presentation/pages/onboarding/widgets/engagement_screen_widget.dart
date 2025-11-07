import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/onboarding_model.dart';

/// Widget for engagement-type onboarding screens
/// Displays title, description, and optional Lottie animation
class EngagementScreenWidget extends StatelessWidget {
  final EngagementScreenModel model;

  const EngagementScreenWidget({
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Visual (Lottie or placeholder)
          if (model.visual != null)
            _buildVisual(model.visual!, width: 200, height: 200)
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: AppColors.backgroundDark,
                size: 60,
              ),
            ),
          const SizedBox(height: 48),

          // Title
          _buildStyledTitle(context, model.title),
          const SizedBox(height: 16),

          // Description (optional)
          if (model.description != null && model.description!.isNotEmpty) ...[
            _buildStyledDescription(context, model.description!),
          ],
        ],
      ),
    );
  }

  Widget _buildVisual(String visualPath, {double width = 200, double height = 200}) {
    // Check if it's an asset path or URL
    if (visualPath.startsWith('http://') || visualPath.startsWith('https://')) {
      // URL - load from network
      return SizedBox(
        width: width,
        height: height,
        child: Lottie.network(visualPath, fit: BoxFit.contain),
      );
    } else if (visualPath.startsWith('assets/')) {
      // Asset path
      return SizedBox(
        width: width,
        height: height,
        child: Lottie.asset(visualPath, fit: BoxFit.contain),
      );
    } else {
      // Assume it's an asset path without prefix
      return SizedBox(
        width: width,
        height: height,
        child: Lottie.asset('assets/$visualPath', fit: BoxFit.contain),
      );
    }
  }

  Widget _buildStyledTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
        color: AppColors.backgroundDark,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    return Text(
      description,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: AppColors.backgroundDark.withValues(alpha: 0.8),
      ),
      textAlign: TextAlign.center,
    );
  }
}

