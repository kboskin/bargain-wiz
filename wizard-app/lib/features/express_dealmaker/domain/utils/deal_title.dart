/// Derives the history title of an Express conversation from the wizard's
/// "seeing" summary, e.g. `IKEA Kallax shelf · $180 · listed 9 days` → `IKEA Kallax shelf`.
class DealTitle {
  DealTitle._();

  static const String untitled = 'Untitled deal';
  static const int maxLength = 40;

  /// First segment before the first "·" (trimmed, at most [maxLength] chars,
  /// ellipsised when cut). Returns [untitled] when [seeing] is empty.
  static String fromSeeing(final String? seeing, {final String fallback = untitled}) {
    if (seeing == null) return fallback;
    final firstSegment = seeing.split('·').first.trim();
    if (firstSegment.isEmpty) return fallback;
    if (firstSegment.length <= maxLength) return firstSegment;
    return '${firstSegment.substring(0, maxLength - 1).trimRight()}…';
  }
}
