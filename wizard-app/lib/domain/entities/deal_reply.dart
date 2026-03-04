import 'package:equatable/equatable.dart';

/// Deal reply from the backend: one or more suggested lines (options).
class DealReply extends Equatable {
  const DealReply({required this.options});

  final List<String> options;

  @override
  List<Object?> get props => [options];
}
