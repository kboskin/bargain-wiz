import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../core/utils/app_logger.dart';
import '../../../domain/repositories/onboarding_repository.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../data/models/onboarding_model.dart';
import '../../bloc/onboarding/onboarding_bloc.dart';
import '../../bloc/onboarding/onboarding_event.dart';
import '../../bloc/onboarding/onboarding_state.dart';
import 'widgets/engagement_screen_widget.dart';
import 'widgets/select_screen_widget.dart';
import 'widgets/slider_screen_widget.dart';

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
          if (state.screens.isEmpty) {
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
                            value: (_currentScreenIndex + 1) / state.screens.length,
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
                      itemCount: state.screens.length,
                      itemBuilder: (context, index) {
                        final screen = state.screens[index];
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
                            state.screens.length,
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
    if (_currentScreenIndex >= state.screens.length) {
      return;
    }
    
    // Validate current step (engagement screens will pass validation automatically)
    if (!_validateCurrentStep(state)) {
      return;
    }

    if (_currentScreenIndex < state.screens.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      bloc.add(const SubmitOnboardingRequested());
    }
  }

  bool _validateCurrentStep(OnboardingConfigLoaded state) {
    if (_currentScreenIndex >= state.screens.length) {
      return false;
    }
    
    final currentScreen = state.screens[_currentScreenIndex];
    
    if (currentScreen.type == 'select') {
      if (state.answers[_currentScreenIndex] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSelectOption),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }
    } else if (currentScreen.type == 'slider') {
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
    if (_currentScreenIndex >= state.screens.length) {
      return AppLocalizations.of(context)!.next;
    }
    
    final currentScreen = state.screens[_currentScreenIndex];
    
    // Use custom button text from model if provided
    if (currentScreen.nextButtonText != null && currentScreen.nextButtonText!.isNotEmpty) {
      return currentScreen.nextButtonText!;
    }
    
    // Fallback to default: "Get Started" for last screen, "Next" for others
    return _currentScreenIndex == state.screens.length - 1
        ? AppLocalizations.of(context)!.getStarted
        : AppLocalizations.of(context)!.next;
  }

  Widget _buildScreen(OnboardingModel screen, int index, OnboardingConfigLoaded state, OnboardingBloc bloc) {
    if (index >= state.screens.length) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.invalidScreenIndex,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
        ),
      );
    }
    
    // Map each screen type to its dedicated widget using polymorphism
    if (screen is EngagementScreenModel) {
      return EngagementScreenWidget(model: screen);
    } else if (screen is SelectScreenModel) {
      return SelectScreenWidget(
        model: screen,
        selectedValue: state.answers[index],
        onOptionSelected: (value) {
          bloc.add(OnboardingAnswerChanged(
            screenIndex: index,
            screenTitle: screen.title,
            screenType: screen.type,
            answerKey: screen.answerStructure?.answerKeyName,
            answer: value,
          ));
        },
      );
    } else if (screen is SliderScreenModel) {
      return SliderScreenWidget(
        model: screen,
        selectedValue: state.answers[index],
        onValueChanged: (value) {
          bloc.add(OnboardingAnswerChanged(
            screenIndex: index,
            screenTitle: screen.title,
            screenType: screen.type,
            answerKey: screen.answerStructure?.answerKeyName,
            answer: value,
          ));
        },
      );
    } else {
      return Center(
        child: Text(
          'Unknown screen type: ${screen.runtimeType}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
        ),
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
}
