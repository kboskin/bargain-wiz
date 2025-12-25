import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/button_style.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/data/models/remote_config/button_config.dart';
import 'package:appwizard/data/models/remote_config/onboarding_model.dart';

/// Widget for permission-type onboarding screens
/// Displays title, description, and permission request button with attractive styling
class PermissionScreenWidget extends StatefulWidget {
  final PermissionScreenModel model;
  final VoidCallback? onContinue;

  const PermissionScreenWidget({
    super.key,
    required this.model,
    this.onContinue,
  });

  @override
  State<PermissionScreenWidget> createState() => _PermissionScreenWidgetState();
}

class _PermissionScreenWidgetState extends State<PermissionScreenWidget> {
  ColorHelper? _cachedColorHelper;
  MultilocaleTextHelper? _cachedMultilocaleTextHelper;
  bool _isRequesting = false;
  AuthorizationStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    // Check current permission status
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    try {
      final messaging = FirebaseService.messaging;
      if (messaging != null) {
        final settings = await messaging.getNotificationSettings();
        if (mounted) {
          setState(() {
            _permissionStatus = settings.authorizationStatus;
          });
        }
      }
    } catch (e) {
      // Ignore errors when checking status
    }
  }

  Future<void> _requestPermission() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    try {
      final settings = await FirebaseService.requestNotificationPermission();
      if (mounted) {
        setState(() {
          _permissionStatus = settings?.authorizationStatus;
          _isRequesting = false;
        });

        // Auto-continue if permission was granted
        if (settings != null &&
            settings.authorizationStatus == AuthorizationStatus.authorized &&
            mounted) {
          widget.onContinue?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cache helper lookups
    _cachedColorHelper ??= di.sl<ColorHelper>();
    _cachedMultilocaleTextHelper ??= di.sl<MultilocaleTextHelper>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          _buildStyledTitle(
            context,
            _cachedMultilocaleTextHelper!.getText(context, widget.model.title),
          ),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null) ...[
            Builder(
              builder: (context) {
                final descriptionText = _cachedMultilocaleTextHelper!.getText(
                  context,
                  widget.model.description,
                );
                if (descriptionText.isNotEmpty) {
                  return Column(
                    children: [
                      _buildStyledDescription(context, descriptionText),
                      const SizedBox(height: 48),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],

          // Permission buttons (configurable array)
          _buildPermissionButtons(context),
        ],
      ),
    );
  }

  Widget _buildStyledTitle(BuildContext context, String title) {
    // Get highlight words from metadata (supports map or list format)
    final highlightWordsData = _getHighlightWords();

    if (highlightWordsData == null ||
        (highlightWordsData is List && highlightWordsData.isEmpty) ||
        (highlightWordsData is Map && highlightWordsData.isEmpty)) {
      // Simple title without highlighting
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

    // Rich text title with highlighted words
    return _buildRichTextTitle(context, title, highlightWordsData);
  }

  /// Build rich text title with highlighted words
  Widget _buildRichTextTitle(
    BuildContext context,
    String title,
    dynamic highlightWordsData,
  ) {
    final parts = title.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();

    // Parse highlight words - can be a map (word -> color) or list (backward compatibility)
    var wordColors = <String, Color>{};
    var highlightWords = <String>[];

    if (highlightWordsData is Map) {
      highlightWordsData.forEach((word, colorValue) {
        final wordStr = word.toString();
        highlightWords.add(wordStr);
        if (colorValue is String) {
          final color = _cachedColorHelper!.getColor(colorValue);
          if (color != null) {
            wordColors[wordStr.toLowerCase()] = color;
          }
        }
      });
    } else if (highlightWordsData is List) {
      highlightWords = highlightWordsData
          .map((item) => item.toString())
          .toList();
    }

    for (var i = 0; i < parts.length; i++) {
      final word = parts[i];
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();

      // Find matching highlight word
      String? matchedWord;
      for (final hw in highlightWords) {
        final cleanHw = hw.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
        if (cleanWord.contains(cleanHw) || cleanHw.contains(cleanWord)) {
          matchedWord = hw;
          break;
        }
      }

      final isHighlight = matchedWord != null;
      final wordColor = isHighlight
          ? (wordColors[matchedWord?.toLowerCase() ?? ''] ??
                defaultHighlightColor)
          : defaultHighlightColor;

      textSpans.add(
        TextSpan(
          text: i > 0 ? ' $word' : word,
          style: isHighlight
              ? TextStyle(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  shadows: [
                    Shadow(
                      color:
                          wordColor?.withValues(alpha: 0.5) ??
                          Colors.transparent,
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  ],
                )
              : Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    // Check if description contains HTML tags
    final hasHtml = RegExp(r'<[^>]+>').hasMatch(description);
    final highlightWordsData = _getDescriptionHighlightWords();
    final highlightColor = _getHighlightColor();

    // If HTML is present, use HTML parsing (takes precedence)
    if (hasHtml) {
      return Html(
        data: description,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            textAlign: TextAlign.center,
            fontSize: FontSize(18),
            color: AppColors.backgroundDark.withValues(alpha: 0.9),
            lineHeight: const LineHeight(1.5),
          ),
          'span.highlight': Style(
            color: highlightColor,
            fontWeight: FontWeight.bold,
            fontSize: FontSize(20),
          ),
          'strong': Style(
            color: highlightColor,
            fontWeight: FontWeight.bold,
            fontSize: FontSize(20),
          ),
        },
      );
    }

    // If highlight words are configured, use keyword-based highlighting
    if (highlightWordsData != null &&
        !(highlightWordsData is List && highlightWordsData.isEmpty) &&
        !(highlightWordsData is Map && highlightWordsData.isEmpty)) {
      return _buildRichTextDescription(
        context,
        description,
        highlightWordsData,
      );
    }

    // Plain text
    return Text(
      description,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: AppColors.backgroundDark.withValues(alpha: 0.9),
        height: 1.5,
        fontSize: 18,
      ),
      textAlign: TextAlign.center,
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

    // Parse highlight words
    Map<String, Color> wordColors = {};
    List<String> highlightWords = [];

    if (highlightWordsData is Map) {
      highlightWordsData.forEach((word, colorValue) {
        final wordStr = word.toString();
        highlightWords.add(wordStr);
        if (colorValue is String) {
          final color = _cachedColorHelper!.getColor(colorValue);
          if (color != null) {
            wordColors[wordStr.toLowerCase()] = color;
          }
        }
      });
    } else if (highlightWordsData is List) {
      highlightWords = highlightWordsData
          .map((item) => item.toString())
          .toList();
    }

    for (final word in parts) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();

      String? matchedWord;
      for (final hw in highlightWords) {
        final cleanHw = hw.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
        if (cleanWord.contains(cleanHw) || cleanHw.contains(cleanWord)) {
          matchedWord = hw;
          break;
        }
      }

      final isHighlight = matchedWord != null;
      final wordColor = isHighlight
          ? (wordColors[matchedWord?.toLowerCase() ?? ''] ??
                defaultHighlightColor)
          : defaultHighlightColor;

      textSpans.add(
        TextSpan(
          text: '$word ',
          style: isHighlight
              ? TextStyle(
                  color: wordColor,
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

  Widget _buildPermissionButtons(BuildContext context) {
    final buttons = _getButtons();

    if (buttons.isEmpty) {
      // Fallback to single button for backward compatibility
      return _buildSingleButton(context);
    }

    // Render multiple buttons side by side
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons.asMap().entries.map((entry) {
        final index = entry.key;
        final buttonConfig = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index > 0 ? 8 : 0,
              right: index < buttons.length - 1 ? 8 : 0,
            ),
            child: _buildButton(context, buttonConfig),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSingleButton(BuildContext context) {
    // Legacy single button support
    final buttonText = _getButtonText();
    final buttonColor = _getButtonColor();
    final glowColor = _getGlowColor();
    final glowIntensity = _getGlowIntensity();
    final buttonStyle = _getButtonStyle();

    final isEnabled =
        !_isRequesting && _permissionStatus != AuthorizationStatus.authorized;

    return _buildStyledButton(
      context: context,
      text: buttonText,
      onPressed: isEnabled ? _requestPermission : null,
      buttonColor: buttonColor,
      glowColor: glowColor,
      glowIntensity: glowIntensity,
      buttonStyle: buttonStyle,
      isLoading: _isRequesting,
    );
  }

  Widget _buildButton(final BuildContext context, ButtonConfig buttonConfig) {
    final text = _getTextFromButtonConfig(buttonConfig);
    final action = buttonConfig.action;
    final buttonColor = _getColorFromString(buttonConfig.buttonColor);
    final glowColor = _getColorFromString(buttonConfig.glowColor);
    final glowIntensity = buttonConfig.glowIntensity ?? 0.6;
    final buttonStyle = buttonConfig.buttonStyle;

    // Determine if button should be enabled based on action
    final isEnabled = action == ButtonAction.requestPermission
        ? (!_isRequesting &&
              _permissionStatus != AuthorizationStatus.authorized)
        : !_isRequesting;

    return _buildStyledButton(
      context: context,
      text: text,
      onPressed: isEnabled ? () => _handleButtonAction(action) : null,
      buttonColor: buttonColor,
      glowColor: glowColor,
      glowIntensity: glowIntensity,
      buttonStyle: buttonStyle,
      isLoading: _isRequesting && action == ButtonAction.requestPermission,
    );
  }

  Widget _buildStyledButton({
    required BuildContext context,
    required String text,
    required VoidCallback? onPressed,
    required Color? buttonColor,
    required Color? glowColor,
    required double glowIntensity,
    required ButtonVisualStyle buttonStyle,
    required bool isLoading,
  }) {
    Widget button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        disabledBackgroundColor: buttonColor?.withValues(alpha: 0.5),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );

    // Apply styling based on button style enum
    switch (buttonStyle) {
      case ButtonVisualStyle.glow:
        if (onPressed != null && glowColor != null) {
          button = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: glowIntensity),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: glowIntensity * 0.6),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: button,
          );
        }
        break;
      case ButtonVisualStyle.gradient:
        // TODO: Implement gradient style if needed
        break;
      case ButtonVisualStyle.flat:
        // Flat style - no special effects
        break;
      case ButtonVisualStyle.outlined:
        // TODO: Implement outlined style if needed
        break;
    }

    return button;
  }

  void _handleButtonAction(ButtonAction action) {
    switch (action) {
      case ButtonAction.requestPermission:
        _requestPermission();
        break;
      case ButtonAction.skip:
      case ButtonAction.dontAllow:
      case ButtonAction.continueAction:
        // Continue to next step
        widget.onContinue?.call();
        break;
    }
  }

  List<ButtonConfig> _getButtons() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('buttons')) {
      final buttonsData = widget.model.metadata!['buttons'];
      if (buttonsData is List) {
        return buttonsData
            .whereType<Map<String, dynamic>>()
            .map((buttonJson) => ButtonConfig.fromJson(buttonJson))
            .toList();
      }
    }
    return [];
  }

  /// Get text from ButtonConfig (supports both string and multilocale)
  String _getTextFromButtonConfig(ButtonConfig config) {
    if (config.text == null) {
      return 'Button';
    }
    if (config.text is String) {
      return config.text as String;
    } else if (config.text is Map<String, dynamic>) {
      return _cachedMultilocaleTextHelper!.getText(context, config.text);
    }
    return 'Button';
  }

  /// Get color from hex string
  Color? _getColorFromString(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }
    return _cachedColorHelper!.getColor(colorString);
  }

  /// Get text from config map (supports both string and multilocale) - legacy method
  String _getTextFromConfig(
    Map<String, dynamic> config,
    String key,
    String defaultValue,
  ) {
    if (config.containsKey(key)) {
      final textData = config[key];
      if (textData is String) {
        return textData;
      } else if (textData is Map<String, dynamic>) {
        return _cachedMultilocaleTextHelper!.getText(context, textData);
      }
    }
    return defaultValue;
  }

  /// Get color from config map (returns null if not found)
  Color? _getColorFromConfig(Map<String, dynamic> config, String key) {
    if (config.containsKey(key)) {
      final colorString = config[key] as String?;
      if (colorString != null && colorString.isNotEmpty) {
        return _cachedColorHelper!.getColor(colorString);
      }
    }
    return null;
  }

  /// Get double value from config map
  double _getDoubleFromConfig(
    Map<String, dynamic> config,
    String key,
    double defaultValue,
  ) {
    if (config.containsKey(key)) {
      final value = config[key];
      if (value is num) {
        return value.toDouble().clamp(0.0, 1.0);
      }
    }
    return defaultValue;
  }

  /// Get button style from config map
  ButtonVisualStyle _getButtonStyleFromConfig(Map<String, dynamic> config) {
    if (config.containsKey('button_style')) {
      final styleString = config['button_style'] as String?;
      if (styleString != null && styleString.isNotEmpty) {
        return ButtonVisualStyle.fromString(styleString);
      }
    }
    return ButtonVisualStyle.glow; // Default style
  }

  // Legacy methods for backward compatibility (single button config)
  String _getButtonText() {
    if (widget.model.metadata != null) {
      return _getTextFromConfig(
        widget.model.metadata!,
        'button_text',
        'Enable Notifications',
      );
    }
    return 'Enable Notifications';
  }

  Color? _getButtonColor() {
    return _getColorFromConfig(widget.model.metadata ?? {}, 'button_color');
  }

  Color? _getGlowColor() {
    return _getColorFromConfig(widget.model.metadata ?? {}, 'glow_color');
  }

  double _getGlowIntensity() {
    return _getDoubleFromConfig(
      widget.model.metadata ?? {},
      'glow_intensity',
      0.6,
    );
  }

  ButtonVisualStyle _getButtonStyle() {
    return _getButtonStyleFromConfig(widget.model.metadata ?? {});
  }

  /// Get highlight words from metadata
  dynamic _getHighlightWords() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('highlight_words')) {
      final highlightWordsData = widget.model.metadata!['highlight_words'];
      if (highlightWordsData is Map<String, dynamic> &&
          highlightWordsData.containsKey('title')) {
        return highlightWordsData['title'];
      }
    }
    return null;
  }

  /// Get description highlight words from metadata
  dynamic _getDescriptionHighlightWords() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('highlight_words')) {
      final highlightWordsData = widget.model.metadata!['highlight_words'];
      if (highlightWordsData is Map<String, dynamic> &&
          highlightWordsData.containsKey('description')) {
        return highlightWordsData['description'];
      }
    }
    return null;
  }

  /// Get highlight color from metadata
  /// Returns null if no valid color is found
  Color? _getHighlightColor() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('highlight_color')) {
      final colorString = widget.model.metadata!['highlight_color'] as String?;
      if (colorString != null && colorString.isNotEmpty) {
        return _cachedColorHelper!.getColor(colorString);
      }
    }
    return null; // No color if not found
  }
}
