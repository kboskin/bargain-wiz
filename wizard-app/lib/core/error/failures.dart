import 'package:equatable/equatable.dart';

/// Base class for all failures
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}

/// Server failure - when API calls fail
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Cache failure - when local storage operations fail
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Network failure - when there's no internet connection
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Validation failure - when input validation fails
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// A turn the backend accepted and then failed to generate.
///
/// [conversationId] is the conversation the backend already owns, so a retry regenerates that
/// deal instead of creating a second one. Null when the call never reached the backend.
class GenerationFailure extends Failure {
  const GenerationFailure(super.message, {this.conversationId});

  final String? conversationId;

  @override
  List<Object> get props => [message, if (conversationId != null) conversationId!];
}
