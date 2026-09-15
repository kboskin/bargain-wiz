import 'package:equatable/equatable.dart';

import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// A single "Lines that land" tip (phrase + bargaining recommendation).
///
/// [text] is multilocale; resolve for the current locale with
/// `TemplateText.textOf(context, tip.text)`.
class LinesThatLandTip extends Equatable {
  const LinesThatLandTip({required this.text});

  final MultilocaleText text;

  @override
  List<Object?> get props => [text];
}
