import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/styled_rich_text_description_widget.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';

/// Widget for slider_lottie-type onboarding screens
/// User selects a percentage (0-100) by interacting with a Lottie animation
class SliderLottieScreenWidget extends StatefulWidget {
  final SliderLottieScreenModel model;
  final dynamic selectedValue;
  final Color? textColor;
  final Function(dynamic) onValueChanged;

  const SliderLottieScreenWidget({
    super.key,
    required this.model,
    this.selectedValue,
    this.textColor,
    required this.onValueChanged,
  });

  @override
  State<SliderLottieScreenWidget> createState() => _SliderLottieScreenWidgetState();
}

class _SliderLottieScreenWidgetState extends State<SliderLottieScreenWidget>
    with TickerProviderStateMixin {
  late final AssetPathHelper _assetPathHelper;
  late final TextHighlightHelper _textHighlightHelper;
  late final ColorHelper _colorHelper;
  late AnimationController _lottieController;
  late AnimationController _breathingController;
  late double _currentPercentage;

  @override
  void initState() {
    super.initState();
    _assetPathHelper = di.sl<AssetPathHelper>();
    _colorHelper = di.sl<ColorHelper>();
    _textHighlightHelper = TextHighlightHelper(_colorHelper);
    
    // Default to 50% if no value is selected
    _currentPercentage = (widget.selectedValue as num?)?.toDouble() ?? 50.0;
    
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    // Set initial frame based on percentage (0-100 map to 0.0-1.0)
    _lottieController.value = _currentPercentage / 100.0;

    // Report default value if not set
    if (widget.selectedValue == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onValueChanged(_currentPercentage);
      });
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _updateValue(double delta, double totalSize) {
    setState(() {
      // Sensitivity: move 100% over the totalSize of the container
      double change = (delta / totalSize) * 100;
      _currentPercentage = (_currentPercentage - change).clamp(0.0, 100.0);
      _lottieController.value = _currentPercentage / 100.0;
    });
    widget.onValueChanged(_currentPercentage.roundToDouble());
  }

  /// Returns the matching option data from config based on percentage
  Map<String, dynamic>? _getOptionForPercentage(double percentage) {
    final options = widget.model.metadata?.options;
    if (options != null && options.isNotEmpty) {
      for (final option in options) {
        if (percentage <= (option['value'] as num).toDouble()) {
          return option as Map<String, dynamic>;
        }
      }
      return options.last as Map<String, dynamic>;
    }
    return null;
  }

  String _getWordWithEmoji(double percentage) {
    final option = _getOptionForPercentage(percentage);
    if (option == null) return '';
    
    final label = (option['label'] as String?) ?? '';
    final emoji = (option['emoji'] as String?) ?? '';
    
    if (emoji.isNotEmpty) {
      return '$emoji $label'.trim();
    }
    return label;
  }

  Color _getTextColor(double percentage) {
    final options = widget.model.metadata?.options;
    if (options == null || options.isEmpty) return AppColors.backgroundDark;

    Map<String, dynamic>? lowerOption;
    Map<String, dynamic>? upperOption;

    for (final dynamic opt in options) {
      final optMap = opt as Map<String, dynamic>;
      final optValue = (optMap['value'] as num).toDouble();
      if (optValue <= percentage) {
        lowerOption = optMap;
      } else {
        upperOption = optMap;
        break;
      }
    }

    if (lowerOption == null && upperOption != null) {
      final cStr = upperOption['color'] as String?;
      return cStr != null ? _colorHelper.getColor(cStr) ?? AppColors.backgroundDark : AppColors.backgroundDark;
    }
    
    if (upperOption == null && lowerOption != null) {
      final cStr = lowerOption['color'] as String?;
      return cStr != null ? _colorHelper.getColor(cStr) ?? AppColors.backgroundDark : AppColors.backgroundDark;
    }

    if (lowerOption != null && upperOption != null) {
      final lowerVal = (lowerOption['value'] as num).toDouble();
      final upperVal = (upperOption['value'] as num).toDouble();
      
      final lowerColorStr = lowerOption['color'] as String?;
      final upperColorStr = upperOption['color'] as String?;
      
      final c1 = lowerColorStr != null ? _colorHelper.getColor(lowerColorStr) ?? AppColors.backgroundDark : AppColors.backgroundDark;
      final c2 = upperColorStr != null ? _colorHelper.getColor(upperColorStr) ?? AppColors.backgroundDark : AppColors.backgroundDark;
      
      final range = upperVal - lowerVal;
      if (range <= 0) return c1;
      
      final t = (percentage - lowerVal) / range;
      return Color.lerp(c1, c2, t) ?? c1;
    }

    return AppColors.backgroundDark;
  }

  @override
  Widget build(BuildContext context) {
    final normalizedPath = _assetPathHelper.normalizeAssetPath(
      widget.model.visual ?? 'assets/lottie/lottie_tube.json',
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: StyledTitleWidget(
            title: widget.model.title.get(context),
            baseColor: widget.textColor ?? AppColors.backgroundDark,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.model.description != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: StyledDescriptionWidget(
              description: widget.model.description!.get(context),
              highlightWordsData: widget.model.metadata?.highlightWords?.description,
              highlightColor: _getHighlightColor(),
              textHighlightHelper: _textHighlightHelper,
              onRichTextDescription: (ctx, desc, data) => StyledRichTextDescriptionWidget(
                description: desc,
                highlightWordsData: data,
                baseColor: widget.textColor ?? AppColors.backgroundDark,
                highlightColor: _getHighlightColor(),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        const Spacer(flex: 1),
          
          // Interactive Lottie Area - Scalable and more compact
          Expanded(
            flex: 10,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                // Use the context size for better sensitivity mapping
                final RenderBox? box = context.findRenderObject() as RenderBox?;
                final double height = box?.size.height ?? 500;
                _updateValue(details.primaryDelta ?? 0, height * 0.8);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Center Tube - Responsive width
                    SizedBox(
                      width: 204, // 20% larger than previous 170
                      child: AnimatedBuilder(
                        animation: _breathingController,
                        builder: (context, child) {
                          // Apply +- 2% breathing effect to the selected percentage
                          final double baseValue = _currentPercentage / 100.0;
                          final double breathingOffset = (_breathingController.value - 0.5) * 0.04;
                          final double animatedValue = (baseValue + breathingOffset).clamp(0.0, 1.0);
                          
                          return Lottie.asset(
                            normalizedPath,
                            controller: _lottieController..value = animatedValue,
                            fit: BoxFit.contain,
                            repeat: false,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Text Below Tube
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _getWordWithEmoji(_currentPercentage),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: _getTextColor(_currentPercentage),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const Spacer(flex: 1),
          
          // Helper hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Swipe the tube to adjust',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.backgroundDark.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const SizedBox(height: 16),
        ],
    );
  }

  /// Get highlight color from metadata
  Color? _getHighlightColor() {
    final colorString = widget.model.metadata?.highlightColor;
    if (colorString != null && colorString.isNotEmpty) {
      return _colorHelper.getColor(colorString);
    }
    return null; // No color if not found
  }
}
