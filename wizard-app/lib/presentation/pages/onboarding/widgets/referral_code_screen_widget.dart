import 'dart:async';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';
import 'package:flutter/material.dart';

/// Widget for referral code-type onboarding screens
/// Allows users to enter a referral code
class ReferralCodeScreenWidget extends StatefulWidget {
  final ReferralCodeScreenModel model;
  final String? selectedValue;
  final Function(String) onValueChanged;

  const ReferralCodeScreenWidget({
    super.key,
    required this.model,
    this.selectedValue,
    required this.onValueChanged,
  });

  @override
  State<ReferralCodeScreenWidget> createState() => _ReferralCodeScreenWidgetState();
}

class _ReferralCodeScreenWidgetState extends State<ReferralCodeScreenWidget> {
  MultilocaleTextHelper? _cachedMultilocaleTextHelper;
  TextHighlightHelper? _cachedTextHighlightHelper;
  ColorHelper? _cachedColorHelper;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Initialize with existing value if available
    if (widget.selectedValue != null) {
      _codeController.text = widget.selectedValue!;
    }
    
    // Save value when text changes (with debounce to avoid too many updates)
    _codeController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // Debounce: only save after user stops typing for 500ms
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onValueChanged(_codeController.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _codeController.removeListener(_onTextChanged);
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cache helper lookups
    _cachedMultilocaleTextHelper ??= di.sl<MultilocaleTextHelper>();
    _cachedColorHelper ??= di.sl<ColorHelper>();
    _cachedTextHighlightHelper ??= TextHighlightHelper(_cachedColorHelper!);

    final title = _cachedMultilocaleTextHelper!.getText(context, widget.model.title);
    final description = widget.model.description != null
        ? _cachedMultilocaleTextHelper!.getText(context, widget.model.description)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          _buildStyledTitle(context, title),
          if (description != null) ...[
            const SizedBox(height: 16),
            // Description
            StyledDescriptionWidget(
              description: description,
              highlightWordsData: _getDescriptionHighlightWords(),
              highlightColor: _getHighlightColor(),
              textHighlightHelper: _cachedTextHighlightHelper!,
            ),
          ],
          const SizedBox(height: 32),

          // Referral Code Input Field
          _buildReferralCodeInput(context),
        ],
      ),
    );
  }

  /// Build styled title
  Widget _buildStyledTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppColors.backgroundDark,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
      textAlign: TextAlign.center,
    );
  }

  /// Build referral code input field
  Widget _buildReferralCodeInput(BuildContext context) {
    return TextField(
      controller: _codeController,
      focusNode: _focusNode,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.backgroundDark,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 2,
          ),
      decoration: InputDecoration(
        hintText: _cachedMultilocaleTextHelper!.getText(
          context,
          widget.model.metadata?.placeholder ?? {'en': 'Enter code', 'es': 'Ingresa código'},
        ),
        hintStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.backgroundDark.withValues(alpha: 0.4),
              fontWeight: FontWeight.normal,
              fontSize: 24,
              letterSpacing: 2,
            ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.backgroundDark.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.backgroundDark.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.backgroundDark,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
    );
  }


  /// Get description highlight words from metadata
  dynamic _getDescriptionHighlightWords() {
    return widget.model.metadata?.highlightWords;
  }

  /// Get highlight color from metadata
  Color? _getHighlightColor() {
    final colorString = widget.model.metadata?.highlightColor;
    if (colorString != null && colorString.isNotEmpty) {
      return _cachedColorHelper?.getColor(colorString);
    }
    return null;
  }
}

