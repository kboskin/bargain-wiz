import 'package:equatable/equatable.dart';
import 'package:appwizard/features/conversation/domain/entities/deal_line.dart';

export 'package:appwizard/features/conversation/domain/entities/deal_line.dart';

/// Deal reply from the backend: what the wizard saw plus one or more suggested lines.
class DealReply extends Equatable {
  const DealReply({required this.lines, this.seeing});

  /// Structured lines (text + intent + why).
  final List<DealLine> lines;
  /// Short summary of what was read from the screenshots, e.g.
  /// `IKEA Kallax shelf · $180 · listed 9 days · "slight scuff"`.
  final String? seeing;

  /// Legacy accessor: plain texts.
  List<String> get options => lines.map((final l) => l.text).toList();

  @override
  List<Object?> get props => [lines, seeing];
}
