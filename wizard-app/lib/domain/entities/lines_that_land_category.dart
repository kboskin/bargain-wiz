import 'package:equatable/equatable.dart';

import 'package:appwizard/domain/entities/lines_that_land_tip.dart';

/// A "Lines that land" category (e.g. Opening lines, Follow-ups) with one daily tip.
class LinesThatLandCategory extends Equatable {
  const LinesThatLandCategory({
    required this.id,
    required this.name,
    required this.dailyTip,
  });

  final String id;
  final String name;
  final LinesThatLandTip dailyTip;

  @override
  List<Object?> get props => [id, name, dailyTip];
}
