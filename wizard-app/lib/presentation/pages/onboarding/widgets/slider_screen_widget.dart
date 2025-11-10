import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/visual_asset_widget.dart';
import '../../../../data/models/onboarding_model.dart';

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

class _SliderScreenWidgetState extends State<SliderScreenWidget> {

  @override
  Widget build(BuildContext context) {
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          _buildStyledTitle(context, widget.model.title),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null && widget.model.description!.isNotEmpty) ...[
            _buildStyledDescription(context, widget.model.description!),
            const SizedBox(height: 48),
          ],

          // Selected value display with optional animation (smooth transitions)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              );
            },
            child: Column(
              key: ValueKey<int>(currentOptionIndex),
              children: [
                // Show animation if available for selected option
                if (currentOption.animation != null) ...[
                  _buildVisual(currentOption.animation!, width: 100, height: 100),
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    currentOption.label,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.backgroundDark,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Animations above slider (if provided) with smooth transitions
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
                          ? AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                              child: _buildVisual(
                                opt.animation!,
                                width: 60,
                                height: 60,
                                key: ValueKey<String>('${opt.animation}_$optIndex'),
                              ),
                            )
                          : AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.backgroundDark.withValues(alpha: 0.2)
                                    : AppColors.backgroundDark.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.backgroundDark
                                      : AppColors.backgroundDark.withValues(alpha: 0.5),
                                ),
                                child: const Icon(
                                  Icons.circle,
                                  size: 30,
                                ),
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
              // Labels below slider with smooth color/weight transitions
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? AppColors.backgroundDark
                                : AppColors.backgroundDark.withValues(alpha: 0.6),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 11,
                          ) ?? const TextStyle(),
                          child: Text(
                            opt.label,
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

  Widget _buildVisual(String visualPath, {double width = 200, double height = 200, Key? key}) {
    return VisualAssetWidget(
      key: key,
      visualPath: visualPath,
      width: width,
      height: height,
    );
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

