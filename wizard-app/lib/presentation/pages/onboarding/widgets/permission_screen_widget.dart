import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/data/models/onboarding_model.dart';

/// Widget for permission-type onboarding screens
/// Displays title, description, and permission request button with attractive styling
class PermissionScreenWidget extends StatefulWidget {
  final PermissionScreenModel model;

  const PermissionScreenWidget({
    super.key,
    required this.model,
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

        // Show brief feedback message
        if (settings != null) {
          final message = settings.authorizationStatus == AuthorizationStatus.authorized
              ? 'Notifications enabled!'
              : settings.authorizationStatus == AuthorizationStatus.denied
                  ? 'Notifications disabled'
                  : null;
          
          if (message != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 2),
                backgroundColor: settings.authorizationStatus == AuthorizationStatus.authorized
                    ? Colors.green
                    : Colors.orange,
              ),
            );
          }
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

          // Permission request button
          _buildPermissionButton(context),
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
    Map<String, Color> wordColors = {};
    List<String> highlightWords = [];

    if (highlightWordsData is Map) {
      highlightWordsData.forEach((word, colorValue) {
        final wordStr = word.toString();
        highlightWords.add(wordStr);
        if (colorValue is String) {
          wordColors[wordStr.toLowerCase()] = _cachedColorHelper!.getColor(
            colorValue,
            defaultColor: defaultHighlightColor,
          );
        }
      });
    } else if (highlightWordsData is List) {
      highlightWords = highlightWordsData.map((item) => item.toString()).toList();
    }

    for (int i = 0; i < parts.length; i++) {
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
          ? (wordColors[matchedWord?.toLowerCase() ?? ''] ?? defaultHighlightColor)
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
                      color: wordColor.withValues(alpha: 0.5),
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
      return _buildRichTextDescription(context, description, highlightWordsData);
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
          wordColors[wordStr.toLowerCase()] = _cachedColorHelper!.getColor(
            colorValue,
            defaultColor: defaultHighlightColor,
          );
        }
      });
    } else if (highlightWordsData is List) {
      highlightWords = highlightWordsData.map((item) => item.toString()).toList();
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
          ? (wordColors[matchedWord?.toLowerCase() ?? ''] ?? defaultHighlightColor)
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

  Widget _buildPermissionButton(BuildContext context) {
    // Get button configuration from metadata
    final buttonText = _getButtonText();
    final buttonColor = _getButtonColor();
    final glowColor = _getGlowColor();
    final glowIntensity = _getGlowIntensity();
    final buttonStyle = _getButtonStyle();

    // Determine if button should be enabled
    final isEnabled = !_isRequesting &&
        _permissionStatus != AuthorizationStatus.authorized;

    // Build button with glow effect
    Widget button = ElevatedButton(
      onPressed: isEnabled ? _requestPermission : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        disabledBackgroundColor: buttonColor.withValues(alpha: 0.5),
      ),
      child: _isRequesting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              buttonText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
    );

    // Apply glow effect if configured
    if (buttonStyle == 'glow' && isEnabled) {
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

    return button;
  }

  String _getButtonText() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('button_text')) {
      final buttonTextData = widget.model.metadata!['button_text'];
      if (buttonTextData is String) {
        return buttonTextData;
      } else if (buttonTextData is Map<String, dynamic>) {
        return _cachedMultilocaleTextHelper!.getText(context, buttonTextData);
      }
    }
    return 'Enable Notifications'; // Default
  }

  Color _getButtonColor() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('button_color')) {
      final colorString = widget.model.metadata!['button_color'] as String?;
      if (colorString != null && colorString.isNotEmpty) {
        return _cachedColorHelper!.getColor(
          colorString,
          defaultColor: const Color(0xFF4ECDC4),
        );
      }
    }
    return const Color(0xFF4ECDC4); // Default teal color
  }

  Color _getGlowColor() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('glow_color')) {
      final colorString = widget.model.metadata!['glow_color'] as String?;
      if (colorString != null && colorString.isNotEmpty) {
        return _cachedColorHelper!.getColor(
          colorString,
          defaultColor: const Color(0xFF4ECDC4),
        );
      }
    }
    return const Color(0xFF4ECDC4); // Default teal color
  }

  double _getGlowIntensity() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('glow_intensity')) {
      final intensity = widget.model.metadata!['glow_intensity'];
      if (intensity is num) {
        return intensity.toDouble().clamp(0.0, 1.0);
      }
    }
    return 0.6; // Default intensity
  }

  String _getButtonStyle() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('button_style')) {
      return widget.model.metadata!['button_style'] as String? ?? 'glow';
    }
    return 'glow'; // Default style
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

  /// Get highlight color from metadata or default
  Color _getHighlightColor() {
    if (widget.model.metadata != null &&
        widget.model.metadata!.containsKey('highlight_color')) {
      final colorString = widget.model.metadata!['highlight_color'] as String?;
      if (colorString != null && colorString.isNotEmpty) {
        return _cachedColorHelper!.getColor(
          colorString,
          defaultColor: const Color(0xFFC47A00),
        );
      }
    }
    return const Color(0xFFC47A00); // Default color
  }
}

