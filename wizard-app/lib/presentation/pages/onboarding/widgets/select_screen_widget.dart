import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart'; // Added for Lottie animations
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/asset_path_helper.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/widgets/glass_container.dart'; // Added for glass effect
import '../../../../data/models/onboarding_model.dart';

/// Widget for select-type onboarding screens
/// Displays title, description, and selectable options
class SelectScreenWidget extends StatefulWidget {
  final SelectScreenModel model;
  final dynamic selectedValue;
  final Function(dynamic) onOptionSelected;

  const SelectScreenWidget({
    super.key,
    required this.model,
    this.selectedValue,
    required this.onOptionSelected,
  });

  @override
  State<SelectScreenWidget> createState() => _SelectScreenWidgetState();
}

enum MagicAnimationType {
  sparkle,
  glowPulse,
  rotatingStars,
  floatingParticles,
  shimmer,
  scalePulse,
  bounce,
  wave,
  pulse,
  rotate,
  orbit,
}

class _SelectScreenWidgetState extends State<SelectScreenWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final List<Animation<double>> _itemAnimations = [];
  final Map<int, MagicAnimationType> _optionAnimationTypes = {};
  final Map<int, AnimationController> _magicControllers = {};
  final Map<int, AnimationController> _waterfallControllers = {}; // Separate controllers for waterfall stars
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    final itemCount = widget.model.options.length;
    // Total duration: each item takes 250ms, appearing one by one with smooth transitions
    final totalDuration = itemCount * 250;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDuration),
    );

    // Create sequential animations - each item appears after the previous one completes
    // Using easeOutCubic for smoother transitions
    for (int i = 0; i < itemCount; i++) {
      final start = i / itemCount; // Start when previous item finishes
      final end = (i + 1) / itemCount; // End when this item finishes
      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            start,
            end,
            curve: Curves.easeOutCubic, // Smoother curve
          ),
        ),
      );
      _itemAnimations.add(animation);
    }

    // Start animation
    _animationController.forward();

    // Assign random magic animation to each option and create controllers
    final animationTypes = MagicAnimationType.values;
    for (int i = 0; i < widget.model.options.length; i++) {
      // Randomly assign an animation type
      _optionAnimationTypes[i] = animationTypes[_random.nextInt(animationTypes.length)];
      
      // Create animation controller for this option's magic effect
      // Use reverse: true to loop smoothly from 0->1->0 without jumping
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1000 + _random.nextInt(1000)), // 1-2 seconds
      )..repeat(reverse: true);
      
      _magicControllers[i] = controller;
      
      // Create separate waterfall controller that always goes forward (top to bottom)
      final waterfallController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500), // Fixed duration for consistent waterfall
      )..repeat(); // Always forward, no reverse
      
      _waterfallControllers[i] = waterfallController;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final controller in _magicControllers.values) {
      controller.dispose();
    }
    _magicControllers.clear();
    for (final controller in _waterfallControllers.values) {
      controller.dispose();
    }
    _waterfallControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.model.options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          _buildStyledTitle(context, widget.model.title),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null && widget.model.description!.isNotEmpty) ...[
            _buildStyledDescription(context, widget.model.description!),
            const SizedBox(height: 32),
          ],

          // Scrollable options list with animations
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.model.options.length,
              itemBuilder: (context, index) {
                final option = widget.model.options[index];
                final isSelected = widget.selectedValue != null &&
                    (option.value == widget.selectedValue ||
                        option.label == widget.selectedValue);
                final animation = index < _itemAnimations.length
                    ? _itemAnimations[index]
                    : const AlwaysStoppedAnimation(1.0);

                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: animation.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - animation.value)),
                        child: Transform.scale(
                          scale: 0.8 + (0.2 * animation.value),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildOptionButton(
                      context,
                      option,
                      isSelected,
                      index,
                      () => widget.onOptionSelected(
                          option.value ?? option.label),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context,
    OnboardingOption option,
    bool isSelected,
    int index,
    VoidCallback onTap,
  ) {
    // Get icon from Font Awesome by name
    IconData? iconData;
    bool isFontAwesome = false;
    if (option.icon != null) {
      final iconResult = _getIconData(option.icon!);
      iconData = iconResult['icon'] as IconData;
      isFontAwesome = iconResult['isFontAwesome'] as bool;
    }

    // Get brand color for this option
    final brandColor = _getBrandColor(option.value ?? option.label);
    final iconColor = isSelected && brandColor != null
        ? brandColor
        : AppColors.backgroundDark;
    final textColor = isSelected && brandColor != null
        ? brandColor
        : AppColors.backgroundDark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: GlassContainer(
        blurSigma: 8.0,
        color: Colors.white,
        opacity: isSelected ? 0.3 : 0.15,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.backgroundDark.withValues(alpha: 0.15),
          width: 0.5,
        ),
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              side: BorderSide.none, // Border handled by GlassContainer
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
            children: [
              if (iconData != null) ...[
                // Animated icon with magic effects
                if (isSelected && _magicControllers.containsKey(index))
                  _buildAnimatedIcon(
                    iconData,
                    iconColor,
                    index,
                    _optionAnimationTypes[index]!,
                    _magicControllers[index]!,
                    isFontAwesome: isFontAwesome,
                  )
                else
                  isFontAwesome
                      ? FaIcon(
                          iconData,
                          color: iconColor,
                          size: 24,
                        )
                      : Icon(
                          iconData,
                          color: iconColor,
                          size: 24,
                        ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              // Magic stars icon to the right when selected
              // Animation and color are configurable per option via metadata
              // Always reserve space to prevent layout jumps
              SizedBox(
                width: 32,
                height: 32,
                child: isSelected && _waterfallControllers.containsKey(index)
                    ? _buildMagicStarAnimation(
                        index,
                        _waterfallControllers[index]!,
                        option, // Pass the option to access its metadata
                      )
                    : const SizedBox.shrink(), // Empty space when not selected
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// Build magic star animation on the right
  /// Animation path and color are configurable per option via metadata
  Widget _buildMagicStarAnimation(
    int index,
    AnimationController waterfallController,
    OnboardingOption option,
  ) {
    // Get animation path from option metadata or use default
    final animationPath = _getAnimationPath(option);
    final assetPathHelper = di.sl<AssetPathHelper>();
    final normalizedPath = assetPathHelper.normalizeAssetPath(animationPath);
    
    // Get animation color from option metadata or use default
    final animationColorString = option.metadata?['animation_color'] as String?;
    final colorHelper = di.sl<ColorHelper>();
    final animationColor = colorHelper.getColor(animationColorString, defaultColor: Colors.amber);
    
    // Single star animation (no waterfall)
    return SizedBox(
      width: 32,
      height: 32,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          animationColor,
          BlendMode.srcATop,
        ),
        child: Lottie.asset(
          normalizedPath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  /// Get animation path from option metadata or default to star_anim.json
  String _getAnimationPath(OnboardingOption option) {
    if (option.metadata != null && option.metadata!.containsKey('animation')) {
      final animation = option.metadata!['animation'];
      if (animation is String && animation.isNotEmpty) {
        return animation;
      }
    }
    return 'assets/lottie/star_anim.json'; // Default path
  }


  /// Build animated icon with magic effects
  Widget _buildAnimatedIcon(
    IconData iconData,
    Color color,
    int index,
    MagicAnimationType type,
    AnimationController controller, {
    bool isFontAwesome = false,
  }) {
    switch (type) {
      case MagicAnimationType.sparkle:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: controller.value * 2 * 3.14159 * 0.1, // Subtle rotation
              child: Transform.scale(
                scale: 1.0 + 0.1 * sin(controller.value * 2 * 3.14159),
                child: isFontAwesome
                    ? FaIcon(
                        iconData,
                        color: color,
                        size: 24,
                      )
                    : Icon(
                        iconData,
                        color: color,
                        size: 24,
                      ),
              ),
            );
          },
        );

      case MagicAnimationType.glowPulse:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + 0.15 * (0.5 + 0.5 * sin(controller.value * 2 * 3.14159)),
              child: isFontAwesome
                  ? FaIcon(
                      iconData,
                      color: color.withValues(
                        alpha: 0.7 + 0.3 * (0.5 + 0.5 * sin(controller.value * 2 * 3.14159)),
                      ),
                      size: 24,
                    )
                  : Icon(
                      iconData,
                      color: color.withValues(
                        alpha: 0.7 + 0.3 * (0.5 + 0.5 * sin(controller.value * 2 * 3.14159)),
                      ),
                      size: 24,
                    ),
            );
          },
        );

      case MagicAnimationType.rotatingStars:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: controller.value * 2 * 3.14159 * 0.2,
              child: Transform.scale(
                scale: 1.0 + 0.1 * sin(controller.value * 4 * 3.14159),
                child: isFontAwesome
                    ? FaIcon(
                        iconData,
                        color: color,
                        size: 24,
                      )
                    : Icon(
                        iconData,
                        color: color,
                        size: 24,
                      ),
              ),
            );
          },
        );

      case MagicAnimationType.floatingParticles:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final offset = sin(controller.value * 2 * 3.14159) * 3;
            return Transform.translate(
              offset: Offset(0, offset),
              child: Transform.scale(
                scale: 1.0 + 0.1 * (0.5 + 0.5 * sin(controller.value * 3 * 3.14159)),
                child: isFontAwesome
                    ? FaIcon(
                        iconData,
                        color: color,
                        size: 24,
                      )
                    : Icon(
                        iconData,
                        color: color,
                        size: 24,
                      ),
              ),
            );
          },
        );

      case MagicAnimationType.shimmer:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + 0.12 * ((controller.value * 1.5) % 1),
              child: isFontAwesome
                  ? FaIcon(
                      iconData,
                      color: color.withValues(
                        alpha: 0.6 + 0.4 * ((controller.value * 1.5) % 1),
                      ),
                      size: 24,
                    )
                  : Icon(
                      iconData,
                      color: color.withValues(
                        alpha: 0.6 + 0.4 * ((controller.value * 1.5) % 1),
                      ),
                      size: 24,
                    ),
            );
          },
        );

      case MagicAnimationType.scalePulse:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final scale = 1.0 + 0.2 * (0.5 + 0.5 * sin(controller.value * 2 * 3.14159));
            return Transform.scale(
              scale: scale,
              child: isFontAwesome
                  ? FaIcon(
                      iconData,
                      color: color,
                      size: 24,
                    )
                  : Icon(
                      iconData,
                      color: color,
                      size: 24,
                    ),
            );
          },
        );

      case MagicAnimationType.bounce:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final offset = sin(controller.value * 3.14159) * 4;
            return Transform.translate(
              offset: Offset(0, -offset.abs()),
              child: Transform.scale(
                scale: 1.0 + 0.1 * sin(controller.value * 3.14159),
                child: isFontAwesome
                    ? FaIcon(
                        iconData,
                        color: color,
                        size: 24,
                      )
                    : Icon(
                        iconData,
                        color: color,
                        size: 24,
                      ),
              ),
            );
          },
        );

      case MagicAnimationType.wave:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final wave = sin(controller.value * 2 * 3.14159);
            return Transform.rotate(
              angle: wave * 0.15, // Subtle wave rotation
              child: Transform.translate(
                offset: Offset(0, wave * 2),
                child: isFontAwesome
                    ? FaIcon(
                        iconData,
                        color: color,
                        size: 24,
                      )
                    : Icon(
                        iconData,
                        color: color,
                        size: 24,
                      ),
              ),
            );
          },
        );

      case MagicAnimationType.pulse:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final pulse = 0.5 + 0.5 * sin(controller.value * 2 * 3.14159);
            return Transform.scale(
              scale: 0.85 + 0.15 * pulse,
              child: Opacity(
                opacity: 0.7 + 0.3 * pulse,
                child: isFontAwesome
                    ? FaIcon(
                        iconData,
                        color: color,
                        size: 24,
                      )
                    : Icon(
                        iconData,
                        color: color,
                        size: 24,
                      ),
              ),
            );
          },
        );

      case MagicAnimationType.rotate:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: controller.value * 2 * 3.14159 * 0.5, // Full rotation over animation
              child: Transform.scale(
                scale: 1.0 + 0.1 * sin(controller.value * 4 * 3.14159),
                child: isFontAwesome
                    ? FaIcon(
                        iconData,
                        color: color,
                        size: 24,
                      )
                    : Icon(
                        iconData,
                        color: color,
                        size: 24,
                      ),
              ),
            );
          },
        );

      case MagicAnimationType.orbit:
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final radius = 3.0;
            final x = cos(controller.value * 2 * 3.14159) * radius;
            final y = sin(controller.value * 2 * 3.14159) * radius;
            return Transform.translate(
              offset: Offset(x, y),
              child: Transform.rotate(
                angle: controller.value * 2 * 3.14159,
                child: isFontAwesome
                    ? FaIcon(
                        iconData,
                        color: color,
                        size: 24,
                      )
                    : Icon(
                        iconData,
                        color: color,
                        size: 24,
                      ),
              ),
            );
          },
        );
    }
  }

  /// Get brand color for platform/service
  Color? _getBrandColor(String value) {
    final brandColors = <String, Color>{
      'tiktok': const Color(0xFF000000), // TikTok black
      'youtube': const Color(0xFFFF0000), // YouTube red
      'google': const Color(0xFF4285F4), // Google blue
      'playstore': const Color(0xFF00D9FF), // Play Store cyan
      'facebook': const Color(0xFF1877F2), // Facebook blue
      'instagram': const Color(0xFFE4405F), // Instagram pink
      'x': const Color(0xFF000000), // X/Twitter black
      'ebay': const Color(0xFF0064D2), // eBay blue
      'amazon': const Color(0xFFFF9900), // Amazon orange
      'craigslist': const Color(0xFF6A2C91), // Craigslist purple
      'friends_or_family': const Color(0xFF10B981), // Green for people
      'other': AppColors.backgroundDark, // Default dark
    };

    return brandColors[value.toLowerCase()];
  }

  /// Get IconData from icon name (Font Awesome or Material Icons)
  /// Maps common icon names to Font Awesome icons where available
  Map<String, dynamic> _getIconData(String iconName) {
    // Map icon names to Font Awesome icons (preferred) or Material Icons (fallback)
    final iconMap = <String, Map<String, dynamic>>{
      'tiktok': {'icon': FontAwesomeIcons.tiktok, 'isFontAwesome': true},
      'youtube': {'icon': FontAwesomeIcons.youtube, 'isFontAwesome': true},
      'google': {'icon': FontAwesomeIcons.google, 'isFontAwesome': true},
      'playstore': {'icon': FontAwesomeIcons.googlePlay, 'isFontAwesome': true},
      'facebook': {'icon': FontAwesomeIcons.facebook, 'isFontAwesome': true},
      'friends_or_family': {'icon': FontAwesomeIcons.users, 'isFontAwesome': true},
      'instagram': {'icon': FontAwesomeIcons.instagram, 'isFontAwesome': true},
      'x': {'icon': FontAwesomeIcons.xTwitter, 'isFontAwesome': true},
      'store': {'icon': FontAwesomeIcons.store, 'isFontAwesome': true},
      'ebay': {'icon': FontAwesomeIcons.ebay, 'isFontAwesome': true},
      'amazon': {'icon': FontAwesomeIcons.amazon, 'isFontAwesome': true},
      'craigslist': {'icon': FontAwesomeIcons.peace, 'isFontAwesome': true}, // Peace icon
      'other': {'icon': Icons.auto_awesome, 'isFontAwesome': false}, // Magical sparkles icon
    };

    return iconMap[iconName.toLowerCase()] ?? {'icon': Icons.help_outline, 'isFontAwesome': false};
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

