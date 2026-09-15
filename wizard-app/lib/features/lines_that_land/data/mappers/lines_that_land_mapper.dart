import 'package:appwizard/features/lines_that_land/data/models/lines_that_land_response.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_tip.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// Maps "Lines that land" DTOs to domain entities.
class LinesThatLandMapper {
  /// Categories with an id, a name and at least one usable line; every text stays
  /// multilocale. [dailyTip] is the day-rotated pick used by the legacy sheet.
  List<LinesThatLandCategory> toCategoryEntities(List<LinesCategoryDto> dtos, int dayIndex) {
    final out = <LinesThatLandCategory>[];
    for (final dto in dtos) {
      if (dto.id.isEmpty || !hasText(dto.name)) continue;
      final tips = [for (final t in dto.tips) if (hasText(t)) LinesThatLandTip(text: t)];
      if (tips.isEmpty) continue;
      out.add(LinesThatLandCategory(
        id: dto.id,
        name: dto.name,
        dailyTip: tips[dayIndex % tips.length],
        tips: tips,
      ));
    }
    return out;
  }

  /// True when the text has a non-blank value in any language (no BuildContext needed).
  static bool hasText(MultilocaleText text) {
    final data = text.toJson();
    if (data is String) return data.trim().isNotEmpty;
    if (data is Map) return data.values.any((v) => v is String && v.trim().isNotEmpty);
    return false;
  }
}
