import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/onboarding_model.dart';

/// Widget for slider-type onboarding screens
/// Supports discrete labeled options with optional animations
class SliderScreenWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Check if this is a discrete slider with options
    if (model.options.isNotEmpty) {
      return _buildDiscreteSlider(context);
    }
    
    // Legacy continuous slider (not used in current implementation)
    return const SizedBox.shrink();
  }

  Widget _buildDiscreteSlider(BuildContext context) {
    // Use the parsed options from the model (already sorted)
    final sliderOptions = List<SliderOption>.from(model.options)
      ..sort((a, b) => a.value.compareTo(b.value));

    // Use normalized slider range (0.0 to 1.0) for smooth sliding
    const double sliderMin = 0.0;
    const double sliderMax = 1.0;

    // Get current selected value
    int currentOptionIndex = 0;

    if (selectedValue != null) {
      final answerValue = (selectedValue as num).toDouble();
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
          _buildStyledTitle(context, model.title),
          const SizedBox(height: 16),

          // Description
          if (model.description.isNotEmpty) ...[
            _buildStyledDescription(context, model.description),
            const SizedBox(height: 48),
          ],

          // Selected value display with optional animation
          Column(
            children: [
              // Show animation if available for selected option
              if (currentOption.animation != null) ...[
                _buildVisual(currentOption.animation!, width: 100, height: 100),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  currentOption.label,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Animations above slider (if provided)
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
                          ? _buildVisual(opt.animation!, width: 60, height: 60)
                          : SizedBox(
                              width: 60,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
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

                  onValueChanged(selectedOption.value);
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
                  onValueChanged(selectedOption.value);
                },
                activeColor: Colors.white,
                inactiveColor: Colors.white.withValues(alpha: 0.3),
              ),
              // Labels below slider
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
                        child: Text(
                          opt.label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    return Text(
      description,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Colors.white.withValues(alpha: 0.8),
      ),
      textAlign: TextAlign.center,
    );
  }
}

