import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/onboarding_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/presentation/bloc/onboarding/onboarding_bloc.dart';
import 'package:appwizard/presentation/bloc/onboarding/onboarding_event.dart';
import 'package:appwizard/presentation/bloc/onboarding/onboarding_state.dart';
import 'widgets/engagement_screen_widget.dart';
import 'widgets/select_screen_widget.dart';
import 'widgets/slider_screen_widget.dart';
import 'widgets/permission_screen_widget.dart';

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
  OnboardingBloc? _cachedBloc;
  MultilocaleTextHelper? _cachedMultilocaleTextHelper;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentScreenIndex != index) {
      setState(() {
        _currentScreenIndex = index;
      });
    }
  }

  void _goToPreviousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cache bloc reference to avoid repeated lookups
    _cachedBloc ??= context.read<OnboardingBloc>();
    _cachedMultilocaleTextHelper ??= di.sl<MultilocaleTextHelper>();
    
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.go('/');
        } else if (state is OnboardingError) {
          // Error state - navigation will be handled by the error UI
        }
      },
      builder: (context, state) {
        if (state is OnboardingLoading || state is OnboardingInitial) {
          return Scaffold(
            backgroundColor: Colors.transparent, // Transparent to show global gradient
            body: Center(
              child: CircularProgressIndicator(color: AppColors.backgroundDark),
            ),
          );
        }

        if (state is OnboardingError) {
          return Scaffold(
            backgroundColor: Colors.transparent, // Transparent to show global gradient
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.backgroundDark),
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
            backgroundColor: Colors.transparent, // Transparent to show global gradient
            body: Center(
              child: Text(
                AppLocalizations.of(context)!.noOnboardingConfig,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.backgroundDark),
              ),
            ),
          );
          }

          return PopScope(
            canPop: _currentScreenIndex == 0,
            onPopInvoked: (didPop) {
              if (!didPop && _currentScreenIndex > 0) {
                _goToPreviousPage();
              }
            },
            child: Scaffold(
              backgroundColor: Colors.transparent, // Transparent to show global gradient
              body: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    // Dark icons for light background
                    statusBarBrightness: Brightness.light,
                    // iOS
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarIconBrightness: Brightness.dark,
                  ),
                  child: SafeArea(
                    child: Stack(
                    children: [
                    // Main content (PageView and bottom controls)
                    Column(
                      children: [
                        // Spacer for top bar (only if current screen shows top bar)
                        if (state.screens.isNotEmpty &&
                            _currentScreenIndex < state.screens.length &&
                            state.screens[_currentScreenIndex].showTopBar)
                          const SizedBox(height: 48 + 32), // Top bar height + padding

                        // PageView for onboarding screens
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            itemCount: state.screens.length,
                            physics: const ClampingScrollPhysics(),
                            padEnds: false,
                            itemBuilder: (context, index) {
                              final screen = state.screens[index];
                              return RepaintBoundary(
                                child: _buildScreen(
                                  screen,
                                  index,
                                  state,
                                  _cachedBloc!,
                                ),
                              );
                            },
                          ),
                        ),

                        // Next/Get Started button
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              // Next/Get Started button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _handleNext(
                                    state,
                                    _cachedBloc!,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.backgroundDark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _getNextButtonText(context, state),
                                    style: AppTextStyles.buttonText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Top bar positioned absolutely (controlled by showTopBar and screen index)
                    if (state.screens.isNotEmpty &&
                        _currentScreenIndex < state.screens.length &&
                        state.screens[_currentScreenIndex].showTopBar)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: RepaintBoundary(
                          child: AnimatedOpacity(
                            opacity: _currentScreenIndex > 0 ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _OnboardingTopBar(
                              key: const ValueKey('onboarding_top_bar'),
                              currentIndex: _currentScreenIndex,
                              totalScreens: state.screens.length,
                              onBackPressed: _currentScreenIndex > 0 ? _goToPreviousPage : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (state is OnboardingSubmitting) {
          return Scaffold(
            backgroundColor: Colors.transparent, // Transparent to show global gradient
            body: Center(
              child: CircularProgressIndicator(color: AppColors.backgroundDark),
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
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

    if (currentScreen is SelectScreenModel) {
      if (state.answers[_currentScreenIndex] == null) {
        // Validation failed - just return false without snackbar
        return false;
      }
    } else if (currentScreen is SliderScreenModel) {
      if (state.answers[_currentScreenIndex] == null) {
        // Validation failed - just return false without snackbar
        return false;
      }
    }
    return true;
  }

  String _getNextButtonText(BuildContext context, OnboardingConfigLoaded state) {
    if (_currentScreenIndex >= state.screens.length) {
      return AppLocalizations.of(context)!.next;
    }

    final currentScreen = state.screens[_currentScreenIndex];

    // Use custom button text from model if provided
    if (currentScreen.nextButtonText != null) {
      final text = _cachedMultilocaleTextHelper!.getText(context, currentScreen.nextButtonText);
      if (text.isNotEmpty) {
        return text;
      }
    }

    // Fallback to default: "Get Started" for last screen, "Next" for others
    return _currentScreenIndex == state.screens.length - 1
        ? AppLocalizations.of(context)!.getStarted
        : AppLocalizations.of(context)!.next;
  }

  Widget _buildScreen(
    OnboardingModel screen,
    int index,
    OnboardingConfigLoaded state,
    OnboardingBloc bloc,
  ) {
    if (index >= state.screens.length) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.invalidScreenIndex,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.backgroundDark),
        ),
      );
    }

    // Map each screen type to its dedicated widget using when pattern matching
    return screen.when<Widget>(
      engagement: (model) => EngagementScreenWidget(model: model),
      select: (model) => SelectScreenWidget(
        model: model,
        selectedValue: state.answers[index],
        onOptionSelected: (value) {
          bloc.add(
            OnboardingAnswerChanged(
              screenIndex: index,
              screenTitle: model.title,
              screenType: model.type,
              answerKey: model.answerStructure?.answerKeyName,
              answer: value,
            ),
          );
        },
      ),
      slider: (model) => SliderScreenWidget(
        model: model,
        selectedValue: state.answers[index],
        onValueChanged: (value) {
          bloc.add(
            OnboardingAnswerChanged(
              screenIndex: index,
              screenTitle: model.title,
              screenType: model.type,
              answerKey: model.answerStructure?.answerKeyName,
              answer: value,
            ),
          );
        },
      ),
      permission: (model) => PermissionScreenWidget(
        model: model,
        onContinue: () => _handleNext(state, _cachedBloc!),
      ),
      orElse: () => Center(
        child: Text(
          'Unknown screen type: ${screen.runtimeType}',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.backgroundDark),
        ),
      ),
    );
  }

}

/// Stable top bar widget for onboarding screen
/// Extracted to prevent rebuilds when page changes
class _OnboardingTopBar extends StatefulWidget {
  final int currentIndex;
  final int totalScreens;
  final VoidCallback? onBackPressed;

  const _OnboardingTopBar({
    super.key,
    required this.currentIndex,
    required this.totalScreens,
    this.onBackPressed,
  });

  @override
  State<_OnboardingTopBar> createState() => _OnboardingTopBarState();
}

class _OnboardingTopBarState extends State<_OnboardingTopBar> {
  double _previousProgress = 0.0;

  @override
  void didUpdateWidget(_OnboardingTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousProgress = (oldWidget.currentIndex + 1) / oldWidget.totalScreens;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetProgress = (widget.currentIndex + 1) / widget.totalScreens;
    
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
      child: SizedBox(
        height: 48, // Fixed height to prevent layout shifts
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Back button (only when available, with left padding)
            if (widget.onBackPressed != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: IconButton(
                  onPressed: widget.onBackPressed,
                  icon: Icon(Icons.arrow_back, color: AppColors.backgroundDark),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Progress bar (takes full remaining space)
            // Edge-to-edge when no back button, with right padding when back button exists
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.onBackPressed != null ? 0.0 : 24.0,
                  right: 24.0,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: _previousProgress,
                    end: targetProgress,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  onEnd: () {
                    setState(() {
                      _previousProgress = targetProgress;
                    });
                  },
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.backgroundDark),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
