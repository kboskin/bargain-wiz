/// Copy for the Lines tab freshness caption, e.g. "Updated today · new lines every day".
/// Cadence comes from the endpoint's `refresh_interval_hours` (see LINES_THAT_LAND.md), so
/// the caption always matches how often the content actually changes.
class LinesFreshness {
  LinesFreshness._();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String describe({required DateTime now, DateTime? updatedAt, Duration? refreshInterval}) {
    final cadence = 'new lines ${cadenceOf(refreshInterval)}';
    if (updatedAt == null) return cadence[0].toUpperCase() + cadence.substring(1);
    return '${updatedLabel(updatedAt, now)} · $cadence';
  }

  /// "every day", "every 3 days", "every week", "every 6 hours"…
  static String cadenceOf(Duration? interval) {
    final d = interval ?? const Duration(hours: 24);
    if (d <= Duration.zero) return 'every day';
    if (d.inDays >= 7) {
      final weeks = d.inDays ~/ 7;
      return weeks == 1 ? 'every week' : 'every $weeks weeks';
    }
    if (d.inDays >= 1) return d.inDays == 1 ? 'every day' : 'every ${d.inDays} days';
    final hours = d.inHours < 1 ? 1 : d.inHours;
    return hours == 1 ? 'every hour' : 'every $hours hours';
  }

  /// "Updated today" / "Updated yesterday" / "Updated Sep 12" (local dates).
  static String updatedLabel(DateTime updatedAt, DateTime now) {
    final at = updatedAt.toLocal();
    final today = DateTime(now.toLocal().year, now.toLocal().month, now.toLocal().day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Updated today';
    if (diff == 1) return 'Updated yesterday';
    return 'Updated ${_months[at.month - 1]} ${at.day}';
  }
}
