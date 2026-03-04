import 'package:equatable/equatable.dart';

/// A single "Lines that land" tip (phrase + bargaining recommendation).
/// Shown to the user on a daily rotation from backend.
class LinesThatLandTip extends Equatable {
  const LinesThatLandTip({required this.text});

  final String text;

  @override
  List<Object?> get props => [text];
}
