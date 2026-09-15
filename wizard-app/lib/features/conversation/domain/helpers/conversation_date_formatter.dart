import 'package:intl/intl.dart';

/// Relative date label for history rows: "Today" / "Yesterday" / "Sep 8" (`DateFormat.MMMd`).
class ConversationDateFormatter {
  ConversationDateFormatter._();

  static String format(
    DateTime date, {
    DateTime? now,
    String today = 'Today',
    String yesterday = 'Yesterday',
    String? locale,
  }) {
    final ref = now ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final refDay = DateTime(ref.year, ref.month, ref.day);
    final diff = refDay.difference(day).inDays;
    if (diff == 0) return today;
    if (diff == 1) return yesterday;
    return monthDay(date, locale: locale);
  }

  /// "Sep 8" in [locale]; falls back to the default locale when its date symbols
  /// have not been initialized (e.g. plain unit tests).
  static String monthDay(DateTime date, {String? locale}) {
    try {
      return DateFormat.MMMd(locale).format(date);
    } on Object {
      return DateFormat.MMMd().format(date);
    }
  }
}
