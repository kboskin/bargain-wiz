import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Derives the display title of a saved [Conversation] (Bargains History rows, Home cards).
///
/// Resolution order:
/// * explicit [Conversation.title] when non-blank;
/// * Express: text before the first "·" of [Conversation.seeing]
///   ("IKEA Kallax shelf · $180 · Facebook" → "IKEA Kallax shelf"), else [expressFallback];
/// * Pro: first non-wizard message, truncated to [maxLength], else [proFallback].
class ConversationTitleHelper {
  ConversationTitleHelper._();

  static const String defaultExpressFallback = 'Screenshot deal';
  static const String defaultProFallback = 'Untitled chat deal';
  static const int defaultMaxLength = 48;

  static String titleOf(
    Conversation conversation, {
    String expressFallback = defaultExpressFallback,
    String proFallback = defaultProFallback,
    int maxLength = defaultMaxLength,
  }) {
    final explicit = _clean(conversation.title);
    if (explicit != null) return explicit;
    switch (conversation.type) {
      case ConversationType.express:
        return fromSeeing(conversation.seeing) ?? expressFallback;
      case ConversationType.proDealCloser:
        final first = firstUserMessage(conversation);
        return first == null ? proFallback : truncate(first, maxLength);
    }
  }

  /// Head of the "seeing" strip: text before the first "·" separator.
  static String? fromSeeing(String? seeing) {
    final s = _clean(seeing);
    if (s == null) return null;
    final head = s.split('·').first.trim();
    return head.isEmpty ? null : head;
  }

  /// First message typed by the user (wizard messages are skipped).
  static String? firstUserMessage(Conversation conversation) {
    for (final m in conversation.messages) {
      if (m.isWizard) continue;
      final t = _clean(m.text);
      if (t != null) return t;
    }
    return null;
  }

  /// Cuts [value] to [maxLength] characters, ending with an ellipsis when shortened.
  static String truncate(String value, int maxLength) {
    if (maxLength <= 0 || value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1).trimRight()}…';
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? null : collapsed;
  }
}
