import 'package:equatable/equatable.dart';

/// Example entity class for domain layer
/// This represents the business logic entities
class ExampleEntity extends Equatable {
  final String id;
  final String name;

  const ExampleEntity({
    required this.id,
    required this.name,
  });

  @override
  List<Object> get props => [id, name];
}

