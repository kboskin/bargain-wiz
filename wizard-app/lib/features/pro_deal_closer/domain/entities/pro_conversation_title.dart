import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Derives the Bargains History title of a Pro Deal Closer conversation:
/// the first user text, whitespace-collapsed and truncated to ~40 characters,
/// or [untitled] when the user only sent attachments (or nothing).
class ProConversationTitle {
  ProConversationTitle._();

  static const String untitled = 'Untitled chat deal';
  static const int maxLength = 40;

  static String derive(Iterable<ProDealCloserMessage> messages) {
    for (final m in messages) {
      if (m.isWizard) continue;
      final text = m.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;
      return truncate(text);
    }
    return untitled;
  }

  /// Cuts [text] to at most [max] characters, preferring a word boundary in
  /// the second half, and appends an ellipsis when something was removed.
  static String truncate(String text, {int max = maxLength}) {
    if (text.length <= max) return text;
    var cut = text.substring(0, max);
    final lastSpace = cut.lastIndexOf(' ');
    if (lastSpace >= max ~/ 2) cut = cut.substring(0, lastSpace);
    return '${cut.trimRight()}…';
  }
}
