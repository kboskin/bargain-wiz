import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart'; // Added for Lottie animations
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/glass_container.dart'; // Added for glass effect
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';

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
  late final AssetPathHelper _assetPathHelper;
  late final ColorHelper _colorHelper;
  late final RemoteConfigService _remoteConfigService;
  late final TextHighlightHelper _textHighlightHelper;

  @override
  void initState() {
    super.initState();
    _assetPathHelper = di.sl<AssetPathHelper>();
    _colorHelper = di.sl<ColorHelper>();
    _remoteConfigService = di.sl<RemoteConfigService>();
    _textHighlightHelper = TextHighlightHelper(_colorHelper);

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
          _buildStyledTitle(context, widget.model.title.get(context)),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null) ...[
            Builder(
              builder: (context) {
                final descriptionText = widget.model.description!.get(context);
                if (descriptionText.isNotEmpty) {
                  return Column(
                    children: [
                      _buildStyledDescription(context, descriptionText),
                      const SizedBox(height: 32),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],

          // Scrollable options list with animations
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.model.options.length,
              itemBuilder: (context, index) {
                final option = widget.model.options[index];
                // Extract text from multilocale value/label for comparison
                final optionValueText = option.value?.get(context);
                final optionLabelText = option.label.get(context);
                final isSelected = widget.selectedValue != null &&
                    (optionValueText == widget.selectedValue ||
                        optionLabelText == widget.selectedValue ||
                        option.value == widget.selectedValue ||
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
                    child: Builder(
                      builder: (context) {
                        final selectedValue = option.value?.get(context) ?? option.label.get(context);
                        return _buildOptionButton(
                          context,
                          option,
                          isSelected,
                          index,
                          () => widget.onOptionSelected(selectedValue),
                        );
                      },
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

    // Get brand color for this option (check tint_color first, then fallback to hardcoded)
    final brandColor = _getBrandColor(option, context);
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
                  option.label.get(context),
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
    final normalizedPath = _assetPathHelper.normalizeAssetPath(animationPath);
    
    // Animation color: option metadata animation_color, else option color, else screen highlight color (was "highlight color", avoid default blue)
    final animationColorString = option.metadata?.animationColor ??
        option.metadata?.color ??
        widget.model.metadata?.highlightColor;
    final animationColor = _colorHelper.getColor(animationColorString);
    
    // Single star animation (no waterfall)
    Widget animationWidget = Lottie.asset(
      normalizedPath,
      fit: BoxFit.contain,
      frameRate: FrameRate(60),
      options: LottieOptions(enableMergePaths: true),
    );
    
    // Apply color filter only if color is provided
    if (animationColor != null) {
      animationWidget = ColorFiltered(
        colorFilter: ColorFilter.mode(
          animationColor,
          BlendMode.srcATop,
        ),
        child: animationWidget,
      );
    }
    
    return SizedBox(
      width: 32,
      height: 32,
      child: animationWidget,
    );
  }

  /// Get animation path from option metadata or default to star_anim.json
  String _getAnimationPath(OnboardingOption option) {
    final animation = option.metadata?.animation;
    if (animation != null && animation.isNotEmpty) {
      return animation;
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
  /// Priority: 1) tint_color from option, 2) color from metadata
  /// Returns null if no valid color is found
  Color? _getBrandColor(OnboardingOption option, BuildContext context) {
    // First priority: Check tint_color from option (per-option override)
    if (option.tintColor != null && option.tintColor!.isNotEmpty) {
      return _colorHelper.getColor(option.tintColor);
    }

    // Second priority: Use color from metadata
    final colorHex = option.metadata?.color;
    if (colorHex != null && colorHex.isNotEmpty) {
      return _colorHelper.getColor(colorHex);
    }

    // Return null (no color) if not found
    return null;
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
      'olx': {'icon': FontAwesomeIcons.store, 'isFontAwesome': true}, // Store icon for OLX
      'craigslist': {'icon': FontAwesomeIcons.peace, 'isFontAwesome': true}, // Peace icon
      'other': {'icon': Icons.auto_awesome, 'isFontAwesome': false}, // Magical sparkles icon
    };

    return iconMap[iconName.toLowerCase()] ?? {'icon': Icons.help_outline, 'isFontAwesome': false};
  }

  Widget _buildStyledTitle(BuildContext context, String title) {
    // Get highlight words from metadata (supports map or list format)
    final highlightWordsData = _getHighlightWords();

    if (highlightWordsData == null ||
        (highlightWordsData is List && highlightWordsData.isEmpty) ||
        (highlightWordsData is Map && highlightWordsData.isEmpty)) {
      // Simple title without highlighting
      return Text(
        title,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: AppColors.backgroundDark,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        textAlign: TextAlign.center,
      );
    }

    // Rich text title with highlighted words (supports per-word colors)
    return _buildRichTextTitle(context, title, highlightWordsData);
  }

  /// Build rich text title with highlighted words (same as welcome screen)
  /// Supports per-word colors via map: {"Bargain": "#FF6B35", "Wiz": "#4ECDC4"}
  /// Or simple list for backward compatibility: ["Bargain", "Wiz"]
  Widget _buildRichTextTitle(
    BuildContext context,
    String title,
    dynamic highlightWordsData,
  ) {
    final parts = title.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();

    // Parse highlight words using helper
    final config = _textHighlightHelper.parseHighlightWords(highlightWordsData);

    for (int i = 0; i < parts.length; i++) {
      final word = parts[i];
      final result = _textHighlightHelper.processWord(word, config, defaultHighlightColor);

      textSpans.add(
        TextSpan(
          text: i > 0 ? ' $word' : word,
          style: result.isHighlight
              ? TextStyle(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  shadows: [
                    Shadow(
                      color: result.wordColor?.withValues(alpha: 0.5) ?? Colors.transparent,
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  ],
                )
              : Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }

  /// Get highlight words from metadata
  dynamic _getHighlightWords() {
    return widget.model.metadata?.highlightWords?.title;
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    final highlightWordsData = _getDescriptionHighlightWords();
    final highlightColor = _getHighlightColor();

    return StyledDescriptionWidget(
      description: description,
      highlightWordsData: highlightWordsData,
      highlightColor: highlightColor,
      textHighlightHelper: _textHighlightHelper,
      onRichTextDescription: _buildRichTextDescription,
    );
  }

  /// Build rich text description with highlighted words.
  /// Supports isHighlight (color), isBold ("bold"), isBoldLarge ("bold_large").
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    dynamic highlightWordsData,
  ) {
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();
    const double bodySize = 18.0;
    const double boldLargeSize = 22.0;

    final config = _textHighlightHelper.parseHighlightWords(highlightWordsData);

    for (final word in parts) {
      final result = _textHighlightHelper.processWord(word, config, defaultHighlightColor);
      final useBold = result.isHighlight || result.isBold || result.isBoldLarge;
      final color = useBold
          ? (result.wordColor ?? defaultHighlightColor ?? AppColors.backgroundDark)
          : AppColors.backgroundDark.withValues(alpha: 0.9);
      final fontSize = result.isBoldLarge ? boldLargeSize : (result.isHighlight || result.isBold ? 20.0 : bodySize);

      textSpans.add(
        TextSpan(
          text: '$word ',
          style: useBold
              ? TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  height: 1.5,
                )
              : Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  height: 1.5,
                  fontSize: bodySize,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }

  /// Get description highlight words from metadata
  dynamic _getDescriptionHighlightWords() {
    return widget.model.metadata?.highlightWords?.description;
  }

  /// Get highlight color from metadata
  /// Returns null if no valid color is found
  Color? _getHighlightColor() {
    final colorString = widget.model.metadata?.highlightColor;
    if (colorString != null && colorString.isNotEmpty) {
      return _colorHelper.getColor(colorString);
    }
    return null; // No color if not found
  }
}

