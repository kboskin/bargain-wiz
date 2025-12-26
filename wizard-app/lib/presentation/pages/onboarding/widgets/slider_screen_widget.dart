import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';

/// Widget for slider-type onboarding screens
/// Supports discrete labeled options with optional animations
class SliderScreenWidget extends StatefulWidget {
  final SliderScreenModel model;
  final dynamic selectedValue;
  final Function(dynamic) onValueChanged;

  const SliderScreenWidget({
    super.key,
    required this.model,
    this.selectedValue,
    required this.onValueChanged,
  });

  @override
  State<SliderScreenWidget> createState() => _SliderScreenWidgetState();
}

class _SliderScreenWidgetState extends State<SliderScreenWidget>
    with SingleTickerProviderStateMixin {
  ColorHelper? _cachedColorHelper;
  MultilocaleTextHelper? _cachedMultilocaleTextHelper;
  AssetPathHelper? _cachedAssetPathHelper;
  TextHighlightHelper? _cachedTextHighlightHelper;
  AnimationController? _staticFrameController;

  @override
  void initState() {
    super.initState();
    // Create a controller for static frames (paused at 0)
    _staticFrameController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _staticFrameController!.value = 0.0; // Set to first frame
    _staticFrameController!.stop(); // Stop animation
    
    // Set default value to first option if no value is selected
    if (widget.selectedValue == null && widget.model.options.isNotEmpty) {
      // Use WidgetsBinding to schedule the callback after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final firstOption = widget.model.options.first;
        widget.onValueChanged(firstOption.value);
      });
    }
  }

  @override
  void dispose() {
    _staticFrameController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cache ColorHelper lookup
    _cachedColorHelper ??= di.sl<ColorHelper>();
    _cachedMultilocaleTextHelper ??= di.sl<MultilocaleTextHelper>();
    _cachedAssetPathHelper ??= di.sl<AssetPathHelper>();
    _cachedTextHighlightHelper ??= TextHighlightHelper(_cachedColorHelper!);
    // Check if this is a discrete slider with options
    if (widget.model.options.isNotEmpty) {
      return _buildDiscreteSlider(context);
    }
    
    // Legacy continuous slider (not used in current implementation)
    return const SizedBox.shrink();
  }

  Widget _buildDiscreteSlider(BuildContext context) {
    // Use the parsed options from the model (already sorted)
    final sliderOptions = List<SliderOption>.from(widget.model.options)
      ..sort((a, b) => a.value.compareTo(b.value));

    // Use normalized slider range (0.0 to 1.0) for smooth sliding
    const double sliderMin = 0.0;
    const double sliderMax = 1.0;

    // Get current selected value
    int currentOptionIndex = 0;

    if (widget.selectedValue != null) {
      final answerValue = (widget.selectedValue as num).toDouble();
      // Find which option index matches the stored value
      for (int i = 0; i < sliderOptions.length; i++) {
        if (sliderOptions[i].value == answerValue) {
          currentOptionIndex = i;
          break;
        }
      }
    }

    // Calculate current slider position (normalized 0.0 to 1.0)
    double currentSliderValue = sliderOptions.length > 1
        ? currentOptionIndex / (sliderOptions.length - 1)
        : 0.0;

    // Find current selected option
    final currentOption = sliderOptions[currentOptionIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Title at the top
          _buildStyledTitle(context, _cachedMultilocaleTextHelper!.getText(context, widget.model.title)),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null) ...[
            Builder(
              builder: (context) {
                final descriptionText = _cachedMultilocaleTextHelper!.getText(context, widget.model.description);
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

          // Spacer to push content to center
          const Spacer(),

          // Big middle animation
          Center(
            child: currentOption.animation != null
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      // Simple smooth cross-fade
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: _buildVisual(
                      currentOption.animation!,
                      width: currentOption.animationWidth ?? 250,
                      height: currentOption.animationHeight ?? 250,
                      fit: BoxFit.cover,
                      key: ValueKey<String>('${currentOption.animation}_$currentOptionIndex'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Spacer to push slider to bottom
          const Spacer(),

          // Text pinned to top of slider
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _cachedMultilocaleTextHelper!.getText(context, currentOption.label),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.backgroundDark,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Static indicators above slider (no animations, greyed out if not selected)
          if (sliderOptions.any((opt) => opt.animation != null)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: sliderOptions.asMap().entries.map((entry) {
                  final opt = entry.value;
                  final optIndex = entry.key;
                  final isSelected = optIndex == currentOptionIndex;

                  return Expanded(
                    child: Center(
                      child: opt.animation != null
                          ? Opacity(
                              opacity: isSelected ? 1.0 : 0.3,
                              child: ColorFiltered(
                                colorFilter: isSelected
                                    ? const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.dst,
                                      )
                                    : const ColorFilter.matrix([
                                        0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                                        0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                                        0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                                        0, 0, 0, 1, 0, // Alpha channel
                                      ]),
                                child: _buildStaticVisual(
                                  opt.animation!,
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.backgroundDark.withValues(alpha: 0.2)
                                    : AppColors.backgroundDark.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.circle,
                                size: 30,
                                color: isSelected
                                    ? AppColors.backgroundDark
                                    : AppColors.backgroundDark.withValues(alpha: 0.3),
                              ),
                            ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Slider with labels
          Column(
            children: [
              Slider(
                value: currentSliderValue,
                min: sliderMin,
                max: sliderMax,
                onChanged: (value) {
                  // Calculate which option based on position percentage
                  final optionIndex = sliderOptions.length > 1
                      ? (value * (sliderOptions.length - 1))
                          .round()
                          .clamp(0, sliderOptions.length - 1)
                      : 0;
                  final selectedOption = sliderOptions[optionIndex];

                  widget.onValueChanged(selectedOption.value);
                },
                onChangeEnd: (value) {
                  // Final snap to nearest option when user releases
                  final optionIndex = sliderOptions.length > 1
                      ? (value * (sliderOptions.length - 1))
                          .round()
                          .clamp(0, sliderOptions.length - 1)
                      : 0;
                  final selectedOption = sliderOptions[optionIndex];

                  // Update to the exact option value for visual consistency
                  widget.onValueChanged(selectedOption.value);
                },
                activeColor: AppColors.backgroundDark,
                inactiveColor: AppColors.backgroundDark.withValues(alpha: 0.3),
              ),
              // Labels below slider with smooth color/weight transitions (bigger text)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: sliderOptions.asMap().entries.map((entry) {
                    final opt = entry.value;
                    final optIndex = entry.key;
                    final isSelected = optIndex == currentOptionIndex;
                    return Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? AppColors.backgroundDark
                                : AppColors.backgroundDark.withValues(alpha: 0.3),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ) ?? const TextStyle(),
                          child: Text(
                            _cachedMultilocaleTextHelper!.getText(context, opt.label),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisual(String visualPath, {double width = 200, double height = 200, BoxFit fit = BoxFit.contain, Key? key}) {
    return VisualAssetWidget(
      key: key,
      visualPath: visualPath,
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Build static visual (no animation) for unselected options
  Widget _buildStaticVisual(String visualPath, {double width = 60, double height = 60}) {
    final lowerPath = visualPath.toLowerCase();
    final isLottie = lowerPath.endsWith('.json');
    final isSvg = lowerPath.endsWith('.svg');
    final normalizedPath = _cachedAssetPathHelper!.normalizeAssetPath(visualPath);
    final isNetworkUrl = _cachedAssetPathHelper!.isNetworkUrl(visualPath);

    Widget visualWidget;

    if (isNetworkUrl) {
      if (isLottie) {
        // Static Lottie - show first frame only, no animation
        // Use controller paused at 0 to show static first frame
        visualWidget = Lottie.network(
          visualPath,
          controller: _staticFrameController,
          fit: BoxFit.contain,
          repeat: false,
          frameRate: FrameRate(60),
          options: LottieOptions(enableMergePaths: true),
        );
      } else if (isSvg) {
        visualWidget = SvgPicture.network(visualPath, fit: BoxFit.contain);
      } else {
        visualWidget = Image.network(visualPath, fit: BoxFit.contain);
      }
    } else {
      // Local asset
      if (isLottie) {
        // Static Lottie - show first frame only, no animation
        // Use controller paused at 0 to show static first frame
        visualWidget = Lottie.asset(
          normalizedPath,
          controller: _staticFrameController,
          fit: BoxFit.contain,
          repeat: false,
          frameRate: FrameRate(60),
          options: LottieOptions(enableMergePaths: true),
        );
      } else if (isSvg) {
        visualWidget = SvgPicture.asset(normalizedPath, fit: BoxFit.contain);
      } else {
        visualWidget = Image.asset(normalizedPath, fit: BoxFit.contain);
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: visualWidget,
    );
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
    final config = _cachedTextHighlightHelper!.parseHighlightWords(highlightWordsData);

    for (int i = 0; i < parts.length; i++) {
      final word = parts[i];
      final result = _cachedTextHighlightHelper!.processWord(word, config, defaultHighlightColor);

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

  /// Get highlight words from metadata (supports map or list format)
  dynamic _getHighlightWords() {
    if (widget.model.metadata != null && widget.model.metadata!.containsKey('highlight_words')) {
      final highlightWordsData = widget.model.metadata!['highlight_words'];
      if (highlightWordsData is Map<String, dynamic> && highlightWordsData.containsKey('title')) {
        return highlightWordsData['title'];
      }
    }
    return null;
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    final highlightWordsData = _getDescriptionHighlightWords();
    final highlightColor = _getHighlightColor();

    return StyledDescriptionWidget(
      description: description,
      highlightWordsData: highlightWordsData,
      highlightColor: highlightColor,
      textHighlightHelper: _cachedTextHighlightHelper!,
      onRichTextDescription: _buildRichTextDescription,
    );
  }

  /// Build rich text description with highlighted words (same as welcome screen)
  /// Supports per-word colors via map: {"the": "#FF6B35", "best": "#4ECDC4", "deal": "#FF6B35"}
  /// Or simple list for backward compatibility: ["the", "best", "deal"]
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    dynamic highlightWordsData,
  ) {
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();

    // Parse highlight words using helper
    final config = _cachedTextHighlightHelper!.parseHighlightWords(highlightWordsData);

    for (final word in parts) {
      final result = _cachedTextHighlightHelper!.processWord(word, config, defaultHighlightColor);

      textSpans.add(
        TextSpan(
          text: '$word ',
          style: result.isHighlight
              ? TextStyle(
                  color: result.wordColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                )
              : Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.backgroundDark.withValues(alpha: 0.9),
                  height: 1.5,
                  fontSize: 18,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }

  /// Get description highlight words from metadata (supports map or list format)
  dynamic _getDescriptionHighlightWords() {
    if (widget.model.metadata != null && widget.model.metadata!.containsKey('highlight_words')) {
      final highlightWordsData = widget.model.metadata!['highlight_words'];
      if (highlightWordsData is Map<String, dynamic> && highlightWordsData.containsKey('description')) {
        return highlightWordsData['description'];
      }
    }
    return null;
  }

  /// Get highlight color from metadata
  /// Returns null if no valid color is found
  Color? _getHighlightColor() {
    if (widget.model.metadata != null && widget.model.metadata!.containsKey('highlight_color')) {
      final colorString = widget.model.metadata!['highlight_color'] as String?;
      if (colorString != null && colorString.isNotEmpty) {
        return _cachedColorHelper!.getColor(colorString);
      }
    }
    return null; // No color if not found
  }
}

