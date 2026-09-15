import 'package:flutter/widgets.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_date_formatter.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_price_helper.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_title_helper.dart';

/// Localized (EN/ES) labels shared by every surface that renders a saved
/// conversation (Bargains History, Home "Your bargains" cards).
class ConversationLabels {
  ConversationLabels._();

  static const Map<String, String> statusOpen = {'en': 'Open', 'es': 'Abierto'};
  static const Map<String, String> statusWon = {'en': 'Won', 'es': 'Ganado'};
  static const Map<String, String> statusLost = {'en': 'Lost', 'es': 'Perdido'};
  static const Map<String, String> today = {'en': 'Today', 'es': 'Hoy'};
  static const Map<String, String> yesterday = {'en': 'Yesterday', 'es': 'Ayer'};
  static const Map<String, String> textDeal = {'en': 'Text deal', 'es': 'Trato por chat'};
  static const Map<String, String> anyMarketplace = {'en': 'Any marketplace', 'es': 'Cualquier mercado'};
  static const Map<String, String> screenshotDeal = {'en': 'Screenshot deal', 'es': 'Trato por captura'};
  static const Map<String, String> untitledChatDeal = {'en': 'Untitled chat deal', 'es': 'Chat sin título'};

  static String of(BuildContext context, Map<String, String> text) =>
      TemplateText.textOf(context, text, fallback: text['en'] ?? '');

  static String statusLabel(BuildContext context, ConversationStatus status) {
    switch (status) {
      case ConversationStatus.open:
        return of(context, statusOpen);
      case ConversationStatus.won:
        return of(context, statusWon);
      case ConversationStatus.lost:
        return of(context, statusLost);
    }
  }

  /// Chip colours per status: (background, text).
  static (Color, Color) statusColors(ConversationStatus status) {
    switch (status) {
      case ConversationStatus.open:
        return (WizColors.statusOpenBg, WizColors.ink);
      case ConversationStatus.won:
        return (WizColors.statusWonBg, WizColors.successText);
      case ConversationStatus.lost:
        return (WizColors.statusLostBg, WizColors.errorText);
    }
  }

  /// Localized title (explicit → auto from seeing / first message → fallback).
  static String title(BuildContext context, Conversation conversation) =>
      ConversationTitleHelper.titleOf(
        conversation,
        expressFallback: of(context, screenshotDeal),
        proFallback: of(context, untitledChatDeal),
      );

  /// "Today" / "Yesterday" / "Sep 8" in the current locale.
  static String date(BuildContext context, DateTime createdAt, {DateTime? now}) =>
      ConversationDateFormatter.format(
        createdAt,
        now: now,
        today: of(context, today),
        yesterday: of(context, yesterday),
        locale: Localizations.maybeLocaleOf(context)?.toString(),
      );

  /// "$420 → $365" / "$180" / "Text deal" (Pro) / null (Express without prices).
  static String? priceLine(BuildContext context, Conversation conversation) =>
      ConversationPriceHelper.priceLine(conversation, textDealLabel: of(context, textDeal));
}
