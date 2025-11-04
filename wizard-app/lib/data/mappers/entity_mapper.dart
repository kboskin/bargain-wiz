import '../../domain/entities/example_entity.dart';
import '../models/example_model.dart';

/// Mapper to convert between domain entities and data models
extension ExampleModelMapper on ExampleModel {
  ExampleEntity toEntity() {
    return ExampleEntity(
      id: id,
      name: name,
    );
  }
}

extension ExampleEntityMapper on ExampleEntity {
  ExampleModel toModel() {
    return ExampleModel(
      id: id,
      name: name,
    );
  }
}

