import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Price / outcome line for history rows: "$420 → $365", "$180", or "Text deal"
/// for Pro conversations without prices. `null` for Express deals without prices.
class ConversationPriceHelper {
  ConversationPriceHelper._();

  static const String defaultTextDealLabel = 'Text deal';
  static const String arrow = '→';

  static String? priceLine(
    Conversation conversation, {
    String textDealLabel = defaultTextDealLabel,
  }) {
    final before = _clean(conversation.priceBefore);
    final after = _clean(conversation.priceAfter);
    if (before != null && after != null) return '$before $arrow $after';
    if (before != null) return before;
    if (after != null) return after;
    return conversation.type == ConversationType.proDealCloser ? textDealLabel : null;
  }

  static String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
