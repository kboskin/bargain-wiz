/// Base class for all exceptions
abstract class AppException implements Exception {
  const AppException(this.message);

  final String message;
}

/// Server exception - when API calls fail
class ServerException extends AppException {
  const ServerException(super.message);
}

/// Cache exception - when local storage operations fail
class CacheException extends AppException {
  const CacheException(super.message);
}

/// Network exception - when there's no internet connection
class NetworkException extends AppException {
  const NetworkException(super.message);
}

