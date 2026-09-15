import 'package:equatable/equatable.dart';

/// One conversational wizard paragraph written in the user's vibe
/// (Pro Deal Closer reply, before "Give me options").
class WizardReply extends Equatable {
  const WizardReply({required this.text});

  final String text;

  @override
  List<Object?> get props => [text];
}
