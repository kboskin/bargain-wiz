import 'dart:async';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:flutter/material.dart';

/// Widget for referral code-type onboarding screens
/// Allows users to enter a referral code
class ReferralCodeScreenWidget extends StatefulWidget {
  final ReferralCodeScreenModel model;
  final String? selectedValue;
  final Color? textColor;
  final Function(String) onValueChanged;

  const ReferralCodeScreenWidget({
    super.key,
    required this.model,
    this.selectedValue,
    this.textColor,
    required this.onValueChanged,
  });

  @override
  State<ReferralCodeScreenWidget> createState() => _ReferralCodeScreenWidgetState();
}

class _ReferralCodeScreenWidgetState extends State<ReferralCodeScreenWidget> {
  late final TextHighlightHelper _textHighlightHelper;
  late final ColorHelper _colorHelper;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _colorHelper = di.sl<ColorHelper>();
    _textHighlightHelper = TextHighlightHelper(_colorHelper);

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
    final title = widget.model.title.get(context);
    final description = widget.model.description?.get(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          StyledTitleWidget(title: title, baseColor: widget.textColor ?? AppColors.backgroundDark),
          if (description != null) ...[
            const SizedBox(height: 16),
            // Description
            StyledDescriptionWidget(
              description: description,
              highlightWordsData: _getDescriptionHighlightWords(),
              highlightColor: _getHighlightColor(),
              textHighlightHelper: _textHighlightHelper,
            ),
          ],
          const SizedBox(height: 32),

          // Referral Code Input Field
          _buildReferralCodeInput(context),
        ],
      ),
    );
  }

  /// Build referral code input field
  Widget _buildReferralCodeInput(final BuildContext context) => TextField(
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
        hintText: (widget.model.metadata?.placeholder ??
                  const MultilocaleText(const {'en': 'Enter code', 'es': 'Ingresa código'})).get(context),
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
          borderSide: const BorderSide(
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
    );


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
}

