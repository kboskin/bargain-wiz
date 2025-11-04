/// Example model class for data layer
/// This represents the data structure from external sources (API, DB, etc.)
class ExampleModel {
  final String id;
  final String name;

  ExampleModel({
    required this.id,
    required this.name,
  });

  factory ExampleModel.fromJson(Map<String, dynamic> json) {
    return ExampleModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

