/// Data model for a "Lines that land" category (id, name, list of tip strings).
class LinesThatLandCategoryModel {
  const LinesThatLandCategoryModel({
    required this.id,
    required this.name,
    required this.tips,
  });

  final String id;
  final String name;
  final List<String> tips;

  /// From raw map (e.g. Remote Config JSON).
  static LinesThatLandCategoryModel? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
    final tipsRaw = json['tips'];
    List<String> tips = const [];
    if (tipsRaw is List) {
      tips = tipsRaw.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return LinesThatLandCategoryModel(id: id, name: name, tips: tips);
  }
}
