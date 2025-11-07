import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/onboarding_model.dart';

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

class _SelectScreenWidgetState extends State<SelectScreenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<Animation<double>> _itemAnimations = [];

  @override
  void initState() {
    super.initState();
    final itemCount = widget.model.options.length;
    // Total duration: each item takes 200ms, appearing one by one
    final totalDuration = itemCount * 200;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDuration),
    );

    // Create sequential animations - each item appears after the previous one completes
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
            curve: Curves.easeOut,
          ),
        ),
      );
      _itemAnimations.add(animation);
    }

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
          _buildStyledTitle(context, widget.model.title),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null && widget.model.description!.isNotEmpty) ...[
            _buildStyledDescription(context, widget.model.description!),
            const SizedBox(height: 32),
          ],

          // Scrollable options list with animations
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.model.options.length,
              itemBuilder: (context, index) {
                final option = widget.model.options[index];
                final isSelected = widget.selectedValue != null &&
                    (option.value == widget.selectedValue ||
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
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildOptionButton(
                      context,
                      option,
                      isSelected,
                      () => widget.onOptionSelected(
                          option.value ?? option.label),
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
    VoidCallback onTap,
  ) {
    // Get icon from Material Icons by name
    IconData? iconData;
    if (option.icon != null) {
      iconData = _getIconData(option.icon!);
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: BorderSide(
            color: isSelected ? AppColors.backgroundDark : AppColors.backgroundDark.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          backgroundColor: isSelected
              ? AppColors.backgroundDark.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            if (iconData != null) ...[
              Icon(
                iconData,
                color: AppColors.backgroundDark,
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                option.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.backgroundDark,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get Material IconData from icon name
  /// Maps common icon names to Material Icons
  IconData? _getIconData(String iconName) {
    // Map icon names to Material Icons
    final iconMap = <String, IconData>{
      'tiktok': Icons.music_note, // Closest match
      'youtube': Icons.play_circle,
      'google': Icons.search,
      'playstore': Icons.store,
      'facebook': Icons.facebook,
      'friends_or_family': Icons.people,
      'instagram': Icons.camera_alt,
      'x': Icons.close, // Twitter/X icon
      'store': Icons.store, // For marketplaces
      'other': Icons.more_horiz,
    };

    return iconMap[iconName.toLowerCase()];
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

