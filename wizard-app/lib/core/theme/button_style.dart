/// Enum for button visual styling options
enum ButtonVisualStyle {
  glow,
  gradient,
  flat,
  outlined;

  /// Convert from string (for Remote Config compatibility)
  static ButtonVisualStyle fromString(String value) {
    switch (value.toLowerCase()) {
      case 'glow':
        return ButtonVisualStyle.glow;
      case 'gradient':
        return ButtonVisualStyle.gradient;
      case 'flat':
        return ButtonVisualStyle.flat;
      case 'outlined':
        return ButtonVisualStyle.outlined;
      default:
        return ButtonVisualStyle.glow; // Default
    }
  }

  /// Convert to string (for serialization)
  String toJson() {
    return name;
  }
}

/// Enum for button action types
enum ButtonAction {
  requestPermission,
  skip,
  dontAllow,
  continueAction;

  /// Convert from string (for Remote Config compatibility)
  static ButtonAction fromString(String value) {
    switch (value.toLowerCase()) {
      case 'request_permission':
        return ButtonAction.requestPermission;
      case 'skip':
        return ButtonAction.skip;
      case 'dont_allow':
        return ButtonAction.dontAllow;
      case 'continue':
        return ButtonAction.continueAction;
      default:
        return ButtonAction.continueAction; // Default
    }
  }

  /// Convert to string (for serialization)
  String toJson() {
    switch (this) {
      case ButtonAction.requestPermission:
        return 'request_permission';
      case ButtonAction.skip:
        return 'skip';
      case ButtonAction.dontAllow:
        return 'dont_allow';
      case ButtonAction.continueAction:
        return 'continue';
    }
  }
}

