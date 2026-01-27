/// Base for entities that support validation.
/// Use generated fromJson/toJson (e.g. json_serializable) for deserialization.
abstract class ValidatableEntity {
  /// Validates the entity; override in subclasses. Default is no-op.
  void validate() {}
}
