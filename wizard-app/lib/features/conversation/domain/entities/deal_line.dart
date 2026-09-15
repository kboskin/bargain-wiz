import 'package:equatable/equatable.dart';

/// Intent tag of a generated negotiation line.
enum DealIntent {
  opener,
  counter,
  close,
  other;

  static DealIntent fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'opener':
      case 'opening':
      case 'open':
        return DealIntent.opener;
      case 'counter':
      case 'counter_offer':
      case 'counteroffer':
        return DealIntent.counter;
      case 'close':
      case 'closing':
        return DealIntent.close;
      default:
        return DealIntent.other;
    }
  }

  /// Display label used in intent tags ("OPENER", "COUNTER", "CLOSE").
  String get label {
    switch (this) {
      case DealIntent.opener:
        return 'Opener';
      case DealIntent.counter:
        return 'Counter';
      case DealIntent.close:
        return 'Close';
      case DealIntent.other:
        return 'Line';
    }
  }
}

/// One copyable negotiation line produced by the wizard, optionally with an
/// intent tag and a short "why this works" explanation.
class DealLine extends Equatable {
  const DealLine({
    required this.text,
    this.intent = DealIntent.other,
    this.why,
  });

  final String text;
  final DealIntent intent;
  final String? why;

  Map<String, dynamic> toJson() => {
        'text': text,
        'intent': intent.name,
        if (why != null) 'why': why,
      };

  factory DealLine.fromJson(Map<String, dynamic> json) => DealLine(
        text: json['text'] as String? ?? '',
        intent: DealIntent.fromString(json['intent'] as String?),
        why: json['why'] as String?,
      );

  /// Accepts either a plain string or a `{text, intent, why}` map.
  static DealLine fromDynamic(dynamic value) {
    if (value is DealLine) return value;
    if (value is String) return DealLine(text: value);
    if (value is Map) return DealLine.fromJson(Map<String, dynamic>.from(value));
    return DealLine(text: value.toString());
  }

  @override
  List<Object?> get props => [text, intent, why];
}
