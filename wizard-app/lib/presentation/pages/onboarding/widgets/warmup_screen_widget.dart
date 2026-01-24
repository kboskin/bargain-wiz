import 'package:flutter/material.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';

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
  ColorHelper? _cachedColorHelper;
  MultilocaleTextHelper? _cachedMultilocaleTextHelper;
  TextHighlightHelper? _cachedTextHighlightHelper;

  @override
  Widget build(BuildContext context) {
    _cachedColorHelper ??= di.sl<ColorHelper>();
    _cachedMultilocaleTextHelper ??= di.sl<MultilocaleTextHelper>();
    _cachedTextHighlightHelper ??= TextHighlightHelper(_cachedColorHelper!);

    final title = _cachedMultilocaleTextHelper!.getText(context, widget.model.title);
    final description = _cachedMultilocaleTextHelper!.getText(context, widget.model.description);

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
              textHighlightHelper: _cachedTextHighlightHelper!,
              onRichTextDescription: _buildRichTextDescription,
            ),
        ],
      ),
    );
  }

  /// Get description highlight words from metadata
  dynamic _getDescriptionHighlightWords() {
    final highlightWordsData = widget.model.metadata?.highlightWords;
    if (highlightWordsData != null && highlightWordsData.containsKey('description')) {
      return highlightWordsData['description'];
    }
    return null;
  }

  /// Get highlight color from metadata
  Color? _getHighlightColor() {
    final colorString = widget.model.metadata?.highlightColor;
    if (colorString != null && colorString.isNotEmpty) {
      return _cachedColorHelper!.getColor(colorString);
    }
    return null;
  }

  Widget _buildVisualArea(BuildContext context) {
    final metadata = widget.model.metadata;
    final alignment = metadata?.sideTextAlignment ?? SideTextAlignment.top;
    
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
        if (metadata?.sideText != null)
          _buildSideText(context, metadata!, alignment),
        
        // Visual
        VisualAssetWidget(
          visualPath: widget.model.visual!,
          width: metadata?.width ?? 200.0,
          height: metadata?.height ?? 200.0,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  Widget _buildSideText(BuildContext context, OnboardingMetadata metadata, SideTextAlignment alignment) {
    final text = _cachedMultilocaleTextHelper!.getText(context, metadata.sideText);
    
    IconData arrowIcon;
    bool iconBelow = true;

    switch (alignment) {
      case SideTextAlignment.bottom:
        arrowIcon = Icons.north_east;
        iconBelow = false;
        break;
      case SideTextAlignment.center:
        arrowIcon = Icons.arrow_forward;
        iconBelow = true;
        break;
      case SideTextAlignment.baseline:
        arrowIcon = Icons.trending_flat;
        iconBelow = true;
        break;
      case SideTextAlignment.top:
      default:
        arrowIcon = Icons.south_east;
        iconBelow = true;
        break;
    }

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
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    dynamic highlightWordsData,
  ) {
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();

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
}
