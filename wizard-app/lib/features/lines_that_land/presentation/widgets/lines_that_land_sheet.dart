import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_bloc.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_event.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_state.dart';

/// Bottom sheet content for "Lines that land". Uses [LinesThatLandBloc];
/// shows loading visual until response, then category cards. Tap a line to copy.
class LinesThatLandSheet extends StatefulWidget {
  const LinesThatLandSheet({
    super.key,
    this.onClose,
    this.showHeader = true,
  });

  final VoidCallback? onClose;
  final bool showHeader;

  @override
  State<LinesThatLandSheet> createState() => _LinesThatLandSheetState();
}

class _LinesThatLandSheetState extends State<LinesThatLandSheet>
    with TickerProviderStateMixin {
  List<Animation<double>> _itemAnimations = [];
  AnimationController? _staggerController;
  bool _loadRequested = false;

  static const String _loadingVisualPath = 'assets/lottie/wizard_hello.json';

  @override
  void dispose() {
    _staggerController?.dispose();
    super.dispose();
  }

  void _initStaggerAnimations(int itemCount) {
    _staggerController?.dispose();
    _staggerController = null;
    _itemAnimations = [];
    if (itemCount <= 0) return;
    const msPerItem = 250;
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: itemCount * msPerItem),
    );
    for (int i = 0; i < itemCount; i++) {
      final start = i / itemCount;
      final end = (i + 1) / itemCount;
      _itemAnimations.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _staggerController!,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }
    _staggerController!.forward();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LinesThatLandBloc, LinesThatLandState>(
      builder: (context, state) {
        if (state is LinesThatLandInitial) {
          if (!_loadRequested) {
            _loadRequested = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<LinesThatLandBloc>().add(const LoadLinesThatLandRequested());
              }
            });
          }
          return _buildLoading(context);
        }
        if (state is LinesThatLandLoading) {
          return _buildLoading(context);
        }
        if (state is LinesThatLandError) {
          return _buildError(context, state.message);
        }
        if (state is LinesThatLandLoaded) {
          final categories = state.categories;
          if (categories.isEmpty) {
            return _buildEmpty(context);
          }
          return _buildList(context, categories);
        }
        return _buildLoading(context);
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Lottie.asset(
                _loadingVisualPath,
                fit: BoxFit.contain,
                repeat: true,
                options: LottieOptions(enableMergePaths: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onClose,
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          Text(
            'Lines that land are coming soon.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<LinesThatLandCategory> categories) {
    if (_itemAnimations.length != categories.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initStaggerAnimations(categories.length);
      });
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final animation = index < _itemAnimations.length
                    ? _itemAnimations[index]
                    : const AlwaysStoppedAnimation(1.0);
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Opacity(
                      opacity: animation.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - animation.value)),
                        child: Transform.scale(
                          scale: 0.92 + (0.08 * animation.value),
                          child: child,
                        ),
                      )
                    ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildCategoryCard(context, category),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (!widget.showHeader || widget.onClose == null) return const SizedBox.shrink();
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onClose,
          color: AppColors.textPrimary,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  static const double _glassBlurSigma = 20.0;
  static const double _glassOpacityCategory = 0.45;
  static const double _glassOpacityPill = 0.35;
  static Border get _glassBorder => Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.5,
      );
  static Border get _glassBorderPill => Border.all(
        color: AppColors.backgroundDark.withValues(alpha: 0.15),
        width: 1,
      );

  Widget _buildCategoryCard(BuildContext context, LinesThatLandCategory category) {
    return GlassContainer(
      blurSigma: _glassBlurSigma,
      color: Colors.white,
      opacity: _glassOpacityCategory,
      borderRadius: BorderRadius.circular(16),
      border: _glassBorder,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.name,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _copyToClipboard(category.dailyTip.text),
            child: GlassContainer(
              blurSigma: _glassBlurSigma,
              color: Colors.white,
              opacity: _glassOpacityPill,
              borderRadius: BorderRadius.circular(12),
              border: _glassBorderPill,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.dailyTip.text,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

