import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/button_style.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/button_with_floating_visual.dart';
import 'package:appwizard/core/widgets/rc_metadata_button.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/styled_rich_text_description_widget.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/shared/data/models/remote_config/button_config.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Widget for permission-type onboarding screens
/// Displays title, description, and permission request button with attractive styling
class PermissionScreenWidget extends StatefulWidget {
  final PermissionScreenModel model;
  final Color? textColor;
  final VoidCallback? onContinue;

  const PermissionScreenWidget({
    super.key,
    required this.model,
    this.textColor,
    this.onContinue,
  });

  @override
  State<PermissionScreenWidget> createState() => _PermissionScreenWidgetState();
}

class _PermissionScreenWidgetState extends State<PermissionScreenWidget> {
  late final ColorHelper _colorHelper;
  late final TextHighlightHelper _textHighlightHelper;
  bool _isRequesting = false;
  AuthorizationStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _colorHelper = di.sl<ColorHelper>();
    _textHighlightHelper = TextHighlightHelper(_colorHelper);
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
    } catch (e, stackTrace) {
      di.sl<AppLogger>().e('Error checking notification permission status', e, stackTrace);
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
        if (settings != null && mounted) {
          widget.onContinue?.call();
        }
      }
    } catch (e, stackTrace) {
      di.sl<AppLogger>().e('Error requesting notification permission', e, stackTrace);
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Visual (optional frame/animation)
          if (widget.model.visual != null) ...[
            _buildVisual(
              widget.model.visual!,
              width: _getVisualWidth(),
              height: _getVisualHeight(),
            ),
            const SizedBox(height: 48),
          ],

          // Title
          StyledTitleWidget(
            title: widget.model.title.get(context),
            baseColor: widget.textColor ?? AppColors.backgroundDark,
            highlightWordsData: widget.model.metadata?.highlightWords?.title,
            highlightColor: widget.model.metadata?.highlightColor,
          ),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null) ...[
            Builder(
              builder: (context) {
                final descriptionText = widget.model.description!.get(context);
                if (descriptionText.isNotEmpty) {
                  return Column(
                    children: [
                      StyledDescriptionWidget(
                      description: descriptionText,
                      highlightWordsData: widget.model.metadata?.highlightWords?.description,
                      highlightColor: _getHighlightColor(),
                      textHighlightHelper: _textHighlightHelper,
                      onRichTextDescription: (ctx, desc, data) => StyledRichTextDescriptionWidget(
                        description: desc,
                        highlightWordsData: data,
                        baseColor: widget.textColor ?? AppColors.backgroundDark,
                        highlightColor: _getHighlightColor(),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
          // Optional animation below the button (metadata.animation) and/or hint with arrow (metadata.sideText + sideTextAlignment)
          if (_hasBelowButtonContent()) ...[
            const SizedBox(height: 24),
            _buildBelowButtonContent(context),
          ],
        ],
      ),
    );
  }

  /// True when metadata has animation and/or sideText for the below-button block
  bool _hasBelowButtonContent() {
    final m = widget.model.metadata;
    if (m == null) return false;
    final hasAnimation =
        m.animation != null && m.animation!.trim().isNotEmpty;
    final hasSideText = m.sideText != null;
    return hasAnimation || hasSideText;
  }

  /// Optional animation + optional hint; order depends on sideTextAlignment so they render sequentially.
  /// Top = hint above (near button), then image; bottom/center/baseline = image then hint.
  Widget _buildBelowButtonContent(BuildContext context) {
    final m = widget.model.metadata!;
    final hasAnimation =
        m.animation != null && m.animation!.trim().isNotEmpty;
    final sideTextStr = m.sideText?.get(context) ?? '';
    final hasSideText = sideTextStr.isNotEmpty;
    final alignment = m.sideTextAlignment ?? SideTextAlignment.top;

    final List<Widget> children = [];
    final showHintFirst = hasSideText && alignment == SideTextAlignment.top;

    if (showHintFirst) {
      children.add(_buildBelowButtonHint(context, m));
      if (hasAnimation) children.add(const SizedBox(height: 12));
    }
    if (hasAnimation) {
      children.add(
        _buildVisual(
          m.animation!,
          width: m.width ?? 120.0,
          height: m.height ?? 120.0,
        ),
      );
      if (hasSideText && !showHintFirst) children.add(const SizedBox(height: 12));
    }
    if (hasSideText && !showHintFirst) {
      children.add(_buildBelowButtonHint(context, m));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// Hint text with arrow; arrow icon and position from sideTextAlignment (same pattern as warmup_screen_widget)
  Widget _buildBelowButtonHint(BuildContext context, OnboardingMetadata metadata) {
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

  Widget _buildPermissionButtons(BuildContext context) {
    final buttons = _getButtons();

    if (buttons.isEmpty) {
      // Fallback to single button for backward compatibility
      return _buildSingleButton(context);
    }

    // Fixed-height row so both buttons get the same size. LayoutBuilder is safe here
    // (no IntrinsicHeight), and SizedBox forces each button to fill its cell.
    const double rowHeight = 64.0;
    return SizedBox(
      height: rowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons.asMap().entries.map((entry) {
          final index = entry.key;
          final buttonConfig = entry.value;
          return Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.only(
                left: index > 0 ? 8 : 0,
                right: index < buttons.length - 1 ? 8 : 0,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return SizedBox(
                    width: cellSize.width,
                    height: cellSize.height,
                    child: _buildButton(context, buttonConfig, cellSize: cellSize),
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSingleButton(BuildContext context) {
    // Legacy single button support - create a ButtonConfig from metadata
    final metadata = widget.model.metadata;
    final buttonText = metadata?.buttonText;
    final buttonColor = metadata?.buttonColor;
    final glowColor = metadata?.glowColor;
    final glowIntensity = metadata?.glowIntensity ?? 0.6;
    final buttonStyleStr = metadata?.buttonStyle;
    final buttonStyle = buttonStyleStr != null 
        ? ButtonVisualStyle.fromString(buttonStyleStr) 
        : ButtonVisualStyle.glow;

    // Create a ButtonConfig for legacy support
    final buttonConfig = ButtonConfig(
      text: buttonText ?? const MultilocaleText({'en': 'Enable Notifications'}),
      action: ButtonAction.requestPermission,
      buttonColor: buttonColor,
      glowColor: glowColor,
      glowIntensity: glowIntensity,
      buttonStyle: buttonStyle,
    );

    // Button is enabled unless currently requesting permission
    final isEnabled = !_isRequesting;

    final button = RCMetadataButton(
      config: buttonConfig,
      onPressed: isEnabled ? _requestPermission : null,
      isLoading: _isRequesting,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      borderRadius: 16,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );

    return ButtonWithFloatingVisual(
      visualPath: widget.model.metadata?.buttonVisual ?? 'assets/lottie/magic_stick_pointer.json',
      visualWidth: widget.model.metadata?.buttonVisualWidth ?? 60.0,
      visualHeight: widget.model.metadata?.buttonVisualHeight ?? 60.0,
      child: button,
    );
  }

  Widget _buildButton(
    final BuildContext context,
    ButtonConfig buttonConfig, {
    Size? cellSize,
  }) {
    final action = buttonConfig.action;

    // Button is enabled unless currently requesting permission
    final isEnabled = !_isRequesting;

    final button = RCMetadataButton(
      config: buttonConfig,
      onPressed: isEnabled ? () => _handleButtonAction(action) : null,
      isLoading: _isRequesting && action == ButtonAction.requestPermission,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      borderRadius: 16,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      fixedSize: cellSize,
    );

    if (action != ButtonAction.requestPermission) return button;

    return ButtonWithFloatingVisual(
      visualPath: widget.model.metadata?.buttonVisual ?? 'assets/lottie/magic_stick_pointer.json',
      visualWidth: widget.model.metadata?.buttonVisualWidth ?? 60.0,
      visualHeight: widget.model.metadata?.buttonVisualHeight ?? 60.0,
      child: button,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      case ButtonAction.copy:
      case ButtonAction.copyCode:
      case ButtonAction.share:
      case ButtonAction.shareCode:
        // These actions are not applicable for permission screens
        // They are handled in ReferralCodeScreenWidget
        break;
    }
  }

  List<ButtonConfig> _getButtons() {
    final buttonsData = widget.model.metadata?.buttons;
    if (buttonsData != null) {
      return buttonsData
          .whereType<Map<String, dynamic>>()
          .map((buttonJson) => ButtonConfig.fromJson(buttonJson))
          .toList();
    }
    return [];
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
        return MultilocaleText.fromJson(textData).get(context);
      }
    }
    return defaultValue;
  }

  /// Get color from config map (returns null if not found)
  Color? _getColorFromConfig(Map<String, dynamic> config, String key) {
    if (config.containsKey(key)) {
      final colorString = config[key] as String?;
      if (colorString != null && colorString.isNotEmpty) {
        return _colorHelper.getColor(colorString);
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

  /// Get highlight words from metadata
  /// Get highlight color from metadata
  Color? _getHighlightColor() {
    final colorString = widget.model.metadata?.highlightColor;
    if (colorString != null && colorString.isNotEmpty) {
      return _colorHelper.getColor(colorString);
    }
    return null; // No color if not found
  }

  /// Get visual width from metadata or default to 200
  double _getVisualWidth() {
    return widget.model.metadata?.width ?? 200.0;
  }

  /// Get visual height from metadata or default to 200
  double _getVisualHeight() {
    return widget.model.metadata?.height ?? 200.0;
  }

  /// Build visual (frame/animation) widget
  Widget _buildVisual(String visualPath, {double width = 200, double height = 200}) {
    return VisualAssetWidget(
      visualPath: visualPath,
      width: width,
      height: height,
    );
  }
}
