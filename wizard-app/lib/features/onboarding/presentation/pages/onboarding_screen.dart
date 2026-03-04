import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/onboarding_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:appwizard/core/routing/app_routes.dart';
import 'widgets/engagement_screen_widget.dart';
import 'widgets/image_list_screen_widget.dart';
import 'widgets/referral_code_screen_widget.dart';
import 'widgets/select_screen_widget.dart';
import 'widgets/slider_screen_widget.dart';
import 'widgets/permission_screen_widget.dart';
import 'widgets/paywall_screen_widget.dart';
import 'widgets/warmup_screen_widget.dart';
import 'widgets/data_upload_screen_widget.dart';
import 'widgets/create_account_screen_widget.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';

class OnboardingFlowPage extends StatelessWidget {
  const OnboardingFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => OnboardingBloc(
            repository: di.sl<OnboardingRepository>(),
            onboardingService: di.sl<OnboardingService>(),
            logger: di.sl<AppLogger>(),
          )..add(const LoadOnboardingConfigRequested()),
        ),
        BlocProvider(
          create: (context) => di.sl<SubscriptionBloc>(),
        ),
      ],
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
  late final OnboardingBloc _onboardingBloc;

  @override
  void initState() {
    super.initState();
    _onboardingBloc = context.read<OnboardingBloc>();
  }

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
    final onboardingGradientConfig =
        di.sl<RemoteConfigService>().getOnboardingConfig()?.background;
    final content = BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.go(AppRoutes.paywall);
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
                    onPressed: () => context.go(AppRoutes.home),
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
                        // Spacer for top bar (always reserve space; bar is invisible when showTopBar is false)
                        if (state.screens.isNotEmpty &&
                            _currentScreenIndex < state.screens.length)
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
                                  _onboardingBloc,
                                  currentPageIndex: _currentScreenIndex,
                                ),
                              );
                            },
                          ),
                        ),

                        // Bottom button area: always reserve space when we have screens; button hidden only for data_upload
                        if (state.screens.isNotEmpty &&
                            _currentScreenIndex < state.screens.length)
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                              child: SizedBox(
                                height: 56,
                                width: double.infinity,
                                child: _shouldShowNextButton(
                                        state.screens[_currentScreenIndex])
                                    ? ElevatedButton(
                                        onPressed: () {
                                          FocusScope.of(context).unfocus();
                                          _handleNext(
                                            state,
                                            _onboardingBloc,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              state.screens[_currentScreenIndex]
                                                      is PaywallScreenModel
                                                  ? Colors.transparent
                                                  : AppColors.backgroundDark,
                                          foregroundColor:
                                              state.screens[_currentScreenIndex]
                                                      is PaywallScreenModel
                                                  ? AppColors.backgroundDark
                                                  : Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: state.screens[
                                                        _currentScreenIndex]
                                                    is PaywallScreenModel
                                                ? BorderSide(
                                                    color:
                                                        AppColors.backgroundDark,
                                                    width: 1,
                                                  )
                                                : BorderSide.none,
                                          ),
                                        ),
                                        child: Text(
                                          _getNextButtonText(context, state),
                                          style: AppTextStyles.buttonText,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Top bar positioned absolutely; invisible (opacity 0) when showTopBar is false
                    if (state.screens.isNotEmpty &&
                        _currentScreenIndex < state.screens.length)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: RepaintBoundary(
                          child: AnimatedOpacity(
                            opacity: state.screens[_currentScreenIndex].showTopBar
                                ? (_currentScreenIndex > 0 ? 1.0 : 0.0)
                                : 0.0,
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
    if (onboardingGradientConfig != null) {
      final colors = onboardingGradientConfig.colorObjects;
      final stops = onboardingGradientConfig.stops;
      if (colors.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                  stops: stops.length == colors.length ? stops : null,
                ),
              ),
            ),
            content,
          ],
        );
      }
    }
    return content;
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

  /// Show the bottom continue/next button. Hidden only for data_upload; all other screens show it.
  bool _shouldShowNextButton(OnboardingModel screen) {
    if (screen.type == OnboardingScreenType.dataUpload) return false;
    return true;
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

    return currentScreen.when(
      paywall: (m) => _getStandardButtonText(context, m, state,
          defaultText: AppLocalizations.of(context)!.skipForNow),
      engagement: (m) => _getStandardButtonText(context, m, state),
      select: (m) => _getStandardButtonText(context, m, state),
      slider: (m) => _getStandardButtonText(context, m, state),
      permission: (m) => _getStandardButtonText(context, m, state),
      imageList: (m) => _getStandardButtonText(context, m, state),
      referralCode: (m) => _getStandardButtonText(context, m, state),
      warmup: (m) => _getStandardButtonText(context, m, state),
      dataUpload: (m) => '', // Button hidden for data upload screen
      createAccount: (m) => _getStandardButtonText(context, m, state),
    );
  }

  Widget _buildDataUploadScreen(
    DataUploadScreenModel model,
    OnboardingConfigLoaded state,
    OnboardingBloc bloc, {
    required int screenIndex,
    required int currentPageIndex,
  }) {
    final isActive = screenIndex == currentPageIndex;
    // Config is inline in the onboarding screen (visual + metadata), same as other screens
    final config = model.toUploadProgressConfig();
    if (config == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.backgroundDark),
            const SizedBox(height: 16),
            Text(
              'Upload screen not configured (missing visual or metadata in onboarding_screens).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.backgroundDark,
                  ),
            ),
          ],
        ),
      );
    }
    final uploadFuture = isActive
        ? di.sl<OnboardingRepository>()
            .uploadUserData(_buildEntityFromState(state))
            .then((r) => r.fold(
                  (f) => throw Exception(f.message),
                  (_) => null,
                ))
        : Completer<void>().future;
    final raw = model.metadata?.raw;
    final highlightWordsData = raw?['highlight_words']?['description'] ?? model.metadata?.highlightWords?.description;
    final highlightColorStr = raw?['highlight_color'] ?? model.metadata?.highlightColor;
    final highlightColor = highlightColorStr != null && highlightColorStr.isNotEmpty
        ? di.sl<ColorHelper>().getColor(highlightColorStr)
        : null;
    return DataUploadScreenWidget(
      config: config,
      uploadFuture: uploadFuture,
      onComplete: () => bloc.add(const SubmitOnboardingRequested()),
      isActivePage: isActive,
      highlightWordsData: highlightWordsData,
      highlightColor: highlightColor,
    );
  }

  OnboardingDataEntity _buildEntityFromState(OnboardingConfigLoaded state) {
    final answers = state.answers.entries.map((entry) {
      final screenIndex = entry.key;
      if (screenIndex >= state.screens.length) return null;
      final screen = state.screens[screenIndex];
      String title = 'Onboarding';
      try {
        final dynamic rawTitle = screen.title;
        if (rawTitle is Map) {
          title = rawTitle['en']?.toString() ??
              rawTitle.values.first?.toString() ??
              'Onboarding';
        } else {
          title = rawTitle?.toString() ?? 'Onboarding';
        }
      } catch (e) {
        di.sl<AppLogger>().w('Error parsing onboarding screen title: $e');
      }
      return OnboardingAnswer(
        screenIndex: screenIndex,
        screenTitle: title,
        screenType: screen.type,
        answerKey: screen.answerStructure?.answerKeyName,
        answer: entry.value,
      );
    }).whereType<OnboardingAnswer>().toList();
    return OnboardingDataEntity(answers: answers, isCompleted: true);
  }

  String _getStandardButtonText(BuildContext context, OnboardingModel screen,
      OnboardingConfigLoaded state,
      {String? defaultText}) {
    if (screen.nextButtonText != null) {
      final text = screen.nextButtonText!.get(context);
      if (text.isNotEmpty) {
        return text;
      }
    }

    if (defaultText != null) {
      return defaultText;
    }

    return _currentScreenIndex == state.screens.length - 1
        ? AppLocalizations.of(context)!.getStarted
        : AppLocalizations.of(context)!.next;
  }

  Widget _buildScreen(
    OnboardingModel screen,
    int index,
    OnboardingConfigLoaded state,
    OnboardingBloc bloc, {
    required int currentPageIndex,
  }) {
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
      dataUpload: (model) => _buildDataUploadScreen(
            model,
            state,
            bloc,
            screenIndex: index,
            currentPageIndex: currentPageIndex,
          ),
      select: (model) => SelectScreenWidget(
        model: model,
        selectedValue: state.answers[index],
        onOptionSelected: (value) {
          bloc.add(
            OnboardingAnswerChanged(
              screenIndex: index,
              screenTitle: model.title.get(context),
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
              screenTitle: model.title.get(context),
              screenType: model.type,
              answerKey: model.answerStructure?.answerKeyName,
              answer: value,
            ),
          );
        },
      ),
      permission: (model) => PermissionScreenWidget(
        model: model,
        onContinue: () => _handleNext(state, _onboardingBloc),
      ),
      imageList: (model) => ImageListScreenWidget(model: model),
      referralCode: (model) => ReferralCodeScreenWidget(
        model: model,
        selectedValue: state.answers[index] as String?,
        onValueChanged: (value) {
          bloc.add(
            OnboardingAnswerChanged(
              screenIndex: index,
              screenTitle: model.title.get(context),
              screenType: model.type,
              answerKey: model.answerStructure?.answerKeyName,
              answer: value,
            ),
          );
        },
      ),
      paywall: (model) => PaywallScreenWidget(
        model: model,
        onClose: kDebugMode
            ? () => context.go(AppRoutes.main)
            : () => _handleNext(state, _onboardingBloc),
      ),
      warmup: (model) => WarmupScreenWidget(model: model),
      createAccount: (model) => CreateAccountScreenWidget(
        model: model,
        onContinue: () => _handleNext(state, _onboardingBloc),
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
