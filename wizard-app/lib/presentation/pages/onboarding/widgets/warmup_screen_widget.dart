import 'package:flutter/material.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';

class WarmupScreenWidget extends StatefulWidget {
  final WarmupScreenModel model;

  const WarmupScreenWidget({
    super.key,
    required this.model,
  });

  @override
  State<WarmupScreenWidget> createState() => _WarmupScreenWidgetState();
}

class _WarmupScreenWidgetState extends State<WarmupScreenWidget> {
  late final ColorHelper _colorHelper;
  late final TextHighlightHelper _textHighlightHelper;

  @override
  void initState() {
    super.initState();
    _colorHelper = di.sl<ColorHelper>();
    _textHighlightHelper = TextHighlightHelper(_colorHelper);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.model.title.get(context);
    final description = widget.model.description?.get(context) ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: AppColors.backgroundDark,
              fontWeight: FontWeight.bold,
              fontSize: 32,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),

          // Visual area with optional side text
          if (widget.model.visual != null)
            _buildVisualArea(context)
          else
            _buildPlaceholderVisual(),
          
          const SizedBox(height: 16),

          // Description
          if (description.isNotEmpty)
            StyledDescriptionWidget(
              description: description,
              highlightWordsData: _getDescriptionHighlightWords(),
              highlightColor: _getHighlightColor(),
              textHighlightHelper: _textHighlightHelper,
              onRichTextDescription: _buildRichTextDescription,
            ),
        ],
      ),
    );
  }

  /// Get description highlight words from metadata
  dynamic _getDescriptionHighlightWords() {
    return widget.model.metadata?.highlightWords?.description;
  }

  /// Get highlight color from metadata
  Color? _getHighlightColor() {
    final colorString = widget.model.metadata?.highlightColor;
    if (colorString != null && colorString.isNotEmpty) {
      return _colorHelper.getColor(colorString);
    }
    return null;
  }

  Widget _buildVisualArea(BuildContext context) {
    final metadata = widget.model.metadata;
    final alignment = metadata?.sideTextAlignment ?? SideTextAlignment.top;
    final hasSideText = metadata?.sideText != null;
    final visual = VisualAssetWidget(
      visualPath: widget.model.visual!,
      width: metadata?.width ?? 200.0,
      height: metadata?.height ?? 200.0,
      fit: BoxFit.contain,
    );

    // Top/bottom: stack hint and visual in order (no overlap), same as permission screen
    if (hasSideText && (alignment == SideTextAlignment.top || alignment == SideTextAlignment.bottom)) {
      if (alignment == SideTextAlignment.top) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSideHintBlock(context, metadata!),
            const SizedBox(height: 12),
            visual,
          ],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          visual,
          const SizedBox(height: 12),
          _buildSideHintBlock(context, metadata!),
        ],
      );
    }

    // Center/baseline: side-by-side row
    if (!hasSideText) return visual;
    CrossAxisAlignment rowAlignment;
    switch (alignment) {
      case SideTextAlignment.bottom:
        rowAlignment = CrossAxisAlignment.end;
        break;
      case SideTextAlignment.center:
        rowAlignment = CrossAxisAlignment.center;
        break;
      case SideTextAlignment.baseline:
        rowAlignment = CrossAxisAlignment.baseline;
        break;
      case SideTextAlignment.top:
      default:
        rowAlignment = CrossAxisAlignment.start;
        break;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: rowAlignment,
      textBaseline: alignment == SideTextAlignment.baseline ? TextBaseline.alphabetic : null,
      children: [
        _buildSideText(context, metadata!, alignment),
        visual,
      ],
    );
  }

  /// Hint block for stacking above/below visual (top/bottom alignment). Same arrow/order logic as permission screen.
  Widget _buildSideHintBlock(BuildContext context, OnboardingMetadata metadata) {
    final text = metadata.sideText?.get(context) ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    final alignment = metadata.sideTextAlignment ?? SideTextAlignment.top;
    final arrowIcon = _arrowIconForAlignment(alignment);
    final iconBelow = _iconBelowForAlignment(alignment);
    final content = <Widget>[
      if (!iconBelow)
        Icon(arrowIcon, color: AppColors.backgroundDark, size: 20),
      Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.backgroundDark,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      if (iconBelow)
        Icon(arrowIcon, color: AppColors.backgroundDark, size: 20),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: content,
    );
  }

  /// Arrow icon: points toward the visual. Top = down (hint above visual), bottom = up (hint below visual).
  IconData _arrowIconForAlignment(SideTextAlignment alignment) {
    switch (alignment) {
      case SideTextAlignment.top:
        return Icons.keyboard_arrow_down;
      case SideTextAlignment.bottom:
        return Icons.keyboard_arrow_up;
      case SideTextAlignment.center:
        return Icons.arrow_forward;
      case SideTextAlignment.baseline:
        return Icons.trending_flat;
      default:
        return Icons.keyboard_arrow_down;
    }
  }

  bool _iconBelowForAlignment(SideTextAlignment alignment) {
    switch (alignment) {
      case SideTextAlignment.bottom:
        return false;
      default:
        return true;
    }
  }

  Widget _buildSideText(BuildContext context, OnboardingMetadata metadata, SideTextAlignment alignment) {
    final text = metadata.sideText?.get(context) ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    final arrowIcon = _arrowIconForAlignment(alignment);
    final iconBelow = _iconBelowForAlignment(alignment);
    final children = <Widget>[
      if (!iconBelow)
        Icon(arrowIcon, color: AppColors.backgroundDark, size: 20),
      Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.backgroundDark,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
      ),
      if (iconBelow)
        Icon(arrowIcon, color: AppColors.backgroundDark, size: 20),
    ];
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: children,
        ),
      ),
    );
  }

  Widget _buildPlaceholderVisual() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_circle_outline,
        color: AppColors.backgroundDark,
        size: 60,
      ),
    );
  }

  /// Build rich text description with highlighted words
  /// Supports isHighlight (color), isBold (bold + highlight_color), isBoldLarge (bold + slightly bigger).
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    dynamic highlightWordsData,
  ) {
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();
    const double bodySize = 18.0;
    const double boldLargeSize = 22.0;

    final config = _textHighlightHelper.parseHighlightWords(highlightWordsData);

    for (final word in parts) {
      final result = _textHighlightHelper.processWord(word, config, defaultHighlightColor);
      final useBold = result.isHighlight || result.isBold || result.isBoldLarge;
      final color = useBold
          ? (result.wordColor ?? defaultHighlightColor ?? AppColors.backgroundDark)
          : AppColors.backgroundDark.withValues(alpha: 0.9);
      final fontSize = result.isBoldLarge ? boldLargeSize : (result.isHighlight ? 20.0 : bodySize);

      textSpans.add(
        TextSpan(
          text: '$word ',
          style: useBold
              ? TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  height: 1.5,
                )
              : Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  height: 1.5,
                  fontSize: bodySize,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }
}
