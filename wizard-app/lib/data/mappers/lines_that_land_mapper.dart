import 'package:appwizard/data/models/lines_that_land_category_model.dart';
import 'package:appwizard/data/models/lines_that_land_tip_model.dart';
import 'package:appwizard/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/domain/entities/lines_that_land_tip.dart';

/// Maps Lines that land data (flat tips and categories) to domain entities.
class LinesThatLandMapper {
  /// Converts raw strings (e.g. from Remote Config) to tip data models.
  List<LinesThatLandTipModel> toModels(List<String> raw) {
    return LinesThatLandTipModel.fromRawList(raw);
  }

  /// Maps tip data models to domain entities.
  List<LinesThatLandTip> toEntities(List<LinesThatLandTipModel> models) {
    return models.map((m) => LinesThatLandTip(text: m.text)).toList();
  }

  /// Returns the tip for the given day index (rotates through the list).
  LinesThatLandTip? toDailyTip(List<LinesThatLandTip> tips, int dayIndex) {
    if (tips.isEmpty) return null;
    return tips[dayIndex % tips.length];
  }

  /// Converts raw category maps (from RC) to category data models.
  List<LinesThatLandCategoryModel> toCategoryModels(List<Map<String, dynamic>> raw) {
    return raw
        .map((m) => LinesThatLandCategoryModel.fromJson(m))
        .whereType<LinesThatLandCategoryModel>()
        .where((c) => c.tips.isNotEmpty)
        .toList();
  }

  /// Maps category models to domain entities, picking one daily tip per category.
  List<LinesThatLandCategory> toCategoryEntities(
    List<LinesThatLandCategoryModel> models,
    int dayIndex,
  ) {
    return models.map((m) {
      final tipIndex = dayIndex % m.tips.length;
      final tipText = m.tips[tipIndex];
      return LinesThatLandCategory(
        id: m.id,
        name: m.name,
        dailyTip: LinesThatLandTip(text: tipText),
      );
    }).toList();
  }
}
