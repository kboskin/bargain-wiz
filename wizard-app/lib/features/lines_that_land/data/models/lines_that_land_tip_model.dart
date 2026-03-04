/// Data model for a single "Lines that land" tip.
/// Raw data from Remote Config is a JSON array of strings; each string is one tip.
class LinesThatLandTipModel {
  const LinesThatLandTipModel({required this.text});

  final String text;

  /// Builds a list of models from the raw list of strings (e.g. from RC).
  static List<LinesThatLandTipModel> fromRawList(List<String> raw) {
    return raw
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => LinesThatLandTipModel(text: s))
        .toList();
  }
}
