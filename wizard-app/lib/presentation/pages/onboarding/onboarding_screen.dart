import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../core/utils/app_logger.dart';
import '../../../domain/repositories/onboarding_repository.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../data/models/onboarding_screen_config.dart';
import '../../bloc/onboarding/onboarding_bloc.dart';
import '../../bloc/onboarding/onboarding_event.dart';
import '../../bloc/onboarding/onboarding_state.dart';

class OnboardingFlowPage extends StatelessWidget {
  const OnboardingFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingBloc(
        repository: di.sl<OnboardingRepository>(),
        onboardingService: di.sl<OnboardingService>(),
        logger: di.sl<AppLogger>(),
      )..add(const LoadOnboardingConfigRequested()),
      child: const _OnboardingFlowView(),
    );
  }
}

class _OnboardingFlowView extends StatefulWidget {
  const _OnboardingFlowView();

  @override
  State<_OnboardingFlowView> createState() => _OnboardingFlowViewState();
}

class _OnboardingFlowViewState extends State<_OnboardingFlowView> {
  final PageController _pageController = PageController();
  int _currentScreenIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentScreenIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.go('/');
        } else if (state is OnboardingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is OnboardingLoading || state is OnboardingInitial) {
          return Scaffold(
            backgroundColor: AppColors.backgroundDark,
            body: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (state is OnboardingError) {
          return Scaffold(
            backgroundColor: AppColors.backgroundDark,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: Text(AppLocalizations.of(context)!.goBack),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is OnboardingConfigLoaded) {
          if (state.config.screens.isEmpty) {
            return Scaffold(
              backgroundColor: AppColors.backgroundDark,
              body: Center(
                child: Text(
                  AppLocalizations.of(context)!.noOnboardingConfig,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: AppColors.backgroundDark,
            body: SafeArea(
              child: Column(
                children: [
                  // Progress bar with back button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      children: [
                        // Back button (only show if not on first screen)
                        if (_currentScreenIndex > 0)
                          IconButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        if (_currentScreenIndex > 0) const SizedBox(width: 16),
                        // Progress bar
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_currentScreenIndex + 1) / state.config.screens.length,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // PageView for onboarding screens
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: state.config.screens.length,
                      itemBuilder: (context, index) {
                        final screen = state.config.screens[index];
                        return _buildScreen(screen, index, state, context.read<OnboardingBloc>());
                      },
                    ),
                  ),

                  // Page indicators and next button
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Page indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            state.config.screens.length,
                            (index) => _buildPageIndicator(index == _currentScreenIndex),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Next/Get Started button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _handleNext(state, context.read<OnboardingBloc>()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.backgroundDark,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _getNextButtonText(state),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is OnboardingSubmitting) {
          return Scaffold(
            backgroundColor: AppColors.backgroundDark,
            body: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _handleNext(OnboardingConfigLoaded state, OnboardingBloc bloc) {
    if (_currentScreenIndex >= state.config.screens.length) {
      return;
    }
    
    final currentScreen = state.config.screens[_currentScreenIndex];
    
    // Validate current step if it's not an engagement screen
    if (currentScreen.type != OnboardingScreenType.engagement) {
      if (!_validateCurrentStep(state)) {
        return;
      }
    }

    if (_currentScreenIndex < state.config.screens.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      bloc.add(const SubmitOnboardingRequested());
    }
  }

  bool _validateCurrentStep(OnboardingConfigLoaded state) {
    if (_currentScreenIndex >= state.config.screens.length) {
      return false;
    }
    
    final currentScreen = state.config.screens[_currentScreenIndex];
    
    if (currentScreen.type == OnboardingScreenType.select) {
      if (state.answers[_currentScreenIndex] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSelectOption),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }
    } else if (currentScreen.type == OnboardingScreenType.slider) {
      if (state.answers[_currentScreenIndex] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSelectValue),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }
    }
    return true;
  }

  String _getNextButtonText(OnboardingConfigLoaded state) {
    if (_currentScreenIndex >= state.config.screens.length) {
      return AppLocalizations.of(context)!.next;
    }
    
    final currentScreen = state.config.screens[_currentScreenIndex];
    
    // Use custom button text from config if provided
    if (currentScreen.nextButtonText != null && currentScreen.nextButtonText!.isNotEmpty) {
      return currentScreen.nextButtonText!;
    }
    
    // Fallback to default: "Get Started" for last screen, "Next" for others
    return _currentScreenIndex == state.config.screens.length - 1
        ? AppLocalizations.of(context)!.getStarted
        : AppLocalizations.of(context)!.next;
  }

  Widget _buildScreen(OnboardingScreenConfig screen, int index, OnboardingConfigLoaded state, OnboardingBloc bloc) {
    if (index >= state.config.screens.length) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.invalidScreenIndex,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
        ),
      );
    }
    
    switch (screen.type) {
      case OnboardingScreenType.engagement:
        return _buildEngagementScreen(screen);
      case OnboardingScreenType.select:
        return _buildSelectScreen(screen, index, state, bloc);
      case OnboardingScreenType.slider:
        return _buildSliderScreen(screen, index, state, bloc);
    }
  }

  Widget _buildEngagementScreen(OnboardingScreenConfig screen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Visual (Lottie or placeholder)
          if (screen.visual != null)
            _buildVisual(screen.visual!, width: 200, height: 200)
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 60,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 48),

          // Title
          _buildStyledTitle(screen.title),
          const SizedBox(height: 24),

          // Description
          _buildStyledDescription(screen.description),
        ],
      ),
    );
  }

  Widget _buildSelectScreen(OnboardingScreenConfig screen, int index, OnboardingConfigLoaded state, OnboardingBloc bloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          _buildStyledTitle(screen.title),
          const SizedBox(height: 16),
          
          // Description
          if (screen.description.isNotEmpty) ...[
            _buildStyledDescription(screen.description),
            const SizedBox(height: 32),
          ],

          // Options
          if (screen.options != null && screen.options!.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: screen.options!.map((option) {
                    final isSelected = state.answers[index] == (option.value ?? option.label);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          bloc.add(OnboardingAnswerChanged(
                            screenIndex: index,
                            screenTitle: screen.title,
                            screenType: screen.type.name,
                            answerKey: screen.answerStructure?.answerKeyName,
                            answer: option.value ?? option.label,
                          ));
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.white : AppColors.borderDark,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            option.label,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: isSelected ? AppColors.backgroundDark : Colors.white,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliderScreen(OnboardingScreenConfig screen, int index, OnboardingConfigLoaded state, OnboardingBloc bloc) {
    // Check if slider has discrete labeled options
    final options = screen.metadata?['options'] as List?;
    
    if (options != null && options.isNotEmpty) {
      return _buildDiscreteSliderScreen(screen, index, state, bloc, options);
    }
    
    // Fallback to continuous slider
    final min = (screen.metadata?['min'] as num?)?.toDouble() ?? 0.0;
    final max = (screen.metadata?['max'] as num?)?.toDouble() ?? 100.0;
    final step = (screen.metadata?['step'] as num?)?.toDouble() ?? 1.0;
    final unit = screen.metadata?['unit'] as String? ?? '';
    final format = screen.metadata?['format'] as String?;
    
    final currentValue = state.answers[index] as num? ?? min;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          _buildStyledTitle(screen.title),
          const SizedBox(height: 16),
          
          // Description
          if (screen.description.isNotEmpty) ...[
            _buildStyledDescription(screen.description),
            const SizedBox(height: 48),
          ],

          // Value display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatValue(currentValue, format, unit),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Slider
          Slider(
            value: currentValue.toDouble(),
            min: min,
            max: max,
            divisions: ((max - min) / step).round(),
            label: _formatValue(currentValue, format, unit),
            onChanged: (value) {
              bloc.add(OnboardingAnswerChanged(
                screenIndex: index,
                screenTitle: screen.title,
                screenType: screen.type.name,
                answerKey: screen.answerStructure?.answerKeyName,
                answer: format == 'currency' ? value : value.round(),
              ));
            },
            activeColor: Colors.white,
            inactiveColor: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscreteSliderScreen(
    OnboardingScreenConfig screen,
    int index,
    OnboardingConfigLoaded state,
    OnboardingBloc bloc,
    List options,
  ) {
    // Parse slider options
    final sliderOptions = options.map((opt) {
      final optMap = opt as Map<String, dynamic>;
      return {
        'value': (optMap['value'] as num).toDouble(),
        'label': optMap['label'] as String,
        'animation': optMap['animation'] as String?, // Optional: Lottie animation path
      };
    }).toList();
    
    // Sort by value
    sliderOptions.sort((a, b) => (a['value'] as double).compareTo(b['value'] as double));
    
    // Use normalized slider range (0.0 to 1.0) for smooth sliding
    const double sliderMin = 0.0;
    const double sliderMax = 1.0;
    
    // Get current selected value
    final currentAnswer = state.answers[index];
    int currentOptionIndex = 0;
    
    if (currentAnswer != null) {
      final answerValue = (currentAnswer as num).toDouble();
      // Find which option index matches the stored value
      for (int i = 0; i < sliderOptions.length; i++) {
        if ((sliderOptions[i]['value'] as double) == answerValue) {
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
          _buildStyledTitle(screen.title),
          const SizedBox(height: 16),
          
          // Description
          if (screen.description.isNotEmpty) ...[
            _buildStyledDescription(screen.description),
            const SizedBox(height: 48),
          ],

          // Selected value display with optional animation
          Column(
            children: [
              // Show animation if available for selected option
              if (currentOption['animation'] != null) ...[
                _buildVisual(currentOption['animation'] as String, width: 100, height: 100),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  currentOption['label'] as String,
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
          if (sliderOptions.any((opt) => opt['animation'] != null)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: sliderOptions.asMap().entries.map((entry) {
                  final opt = entry.value;
                  final optIndex = entry.key;
                  final isSelected = optIndex == currentOptionIndex;
                  final animation = opt['animation'] as String?;
                  
                  return Expanded(
                    child: Center(
                      child: animation != null
                          ? _buildVisual(animation, width: 60, height: 60)
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
                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
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
                      ? (value * (sliderOptions.length - 1)).round().clamp(0, sliderOptions.length - 1)
                      : 0;
                  final selectedOption = sliderOptions[optionIndex];
                  final selectedValue = selectedOption['value'] as double;
                  
                  bloc.add(OnboardingAnswerChanged(
                    screenIndex: index,
                    screenTitle: screen.title,
                    screenType: screen.type.name,
                    answerKey: screen.answerStructure?.answerKeyName,
                    answer: selectedValue,
                  ));
                },
                onChangeEnd: (value) {
                  // Final snap to nearest option when user releases
                  final optionIndex = sliderOptions.length > 1
                      ? (value * (sliderOptions.length - 1)).round().clamp(0, sliderOptions.length - 1)
                      : 0;
                  final selectedOption = sliderOptions[optionIndex];
                  final selectedValue = selectedOption['value'] as double;
                  
                  // Update to the exact option value for visual consistency
                  bloc.add(OnboardingAnswerChanged(
                    screenIndex: index,
                    screenTitle: screen.title,
                    screenType: screen.type.name,
                    answerKey: screen.answerStructure?.answerKeyName,
                    answer: selectedValue,
                  ));
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
                          opt['label'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
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

  String _formatValue(num value, String? format, String unit) {
    if (format == 'currency') {
      return '\$${value.toStringAsFixed(0)}';
    }
    return '$value $unit';
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
      // Try as asset path (assume it's in assets/)
      return SizedBox(
        width: width,
        height: height,
        child: Lottie.asset('assets/$visualPath', fit: BoxFit.contain),
      );
    }
  }

  Widget _buildPageIndicator(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildStyledTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStyledDescription(String description) {
    final keywords = ['bargain', 'bargaining', 'deal', 'best', 'analysis', 'negotiate', 'negotiation', 'smart', 'ai'];
    final pattern = '\\b(${keywords.join('|')})\\b';
    final matches = RegExp(pattern, caseSensitive: false).allMatches(description);
    
    if (matches.isEmpty) {
      return Text(
        description,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
        textAlign: TextAlign.center,
      );
    }
    
    final spans = <TextSpan>[];
    int lastIndex = 0;
    
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: description.substring(lastIndex, match.start),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.5,
              ),
        ));
      }
      
      spans.add(TextSpan(
        text: description.substring(match.start, match.end),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.amber,
          fontWeight: FontWeight.bold,
          height: 1.5,
          shadows: [
            Shadow(
              color: Colors.amber.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ));
      
      lastIndex = match.end;
    }
    
    if (lastIndex < description.length) {
      spans.add(TextSpan(
        text: description.substring(lastIndex),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
      ));
    }
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }
}
