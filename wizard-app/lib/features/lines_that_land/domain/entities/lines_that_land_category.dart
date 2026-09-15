import 'package:equatable/equatable.dart';

import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_tip.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// A "Lines that land" category (e.g. Opening lines, Follow-ups).
///
/// [name] is multilocale (resolve with `TemplateText.textOf`). [tips] holds every
/// configured line; [dailyTip] is the day-rotated pick used by the legacy sheet.
class LinesThatLandCategory extends Equatable {
  const LinesThatLandCategory({
    required this.id,
    required this.name,
    required this.dailyTip,
    this.tips = const [],
  });

  final String id;
  final MultilocaleText name;
  final LinesThatLandTip dailyTip;
  final List<LinesThatLandTip> tips;

  /// All lines, falling back to the daily tip when only that was provided.
  List<LinesThatLandTip> get allTips => tips.isEmpty ? [dailyTip] : tips;

  @override
  List<Object?> get props => [id, name, dailyTip, tips];
}
