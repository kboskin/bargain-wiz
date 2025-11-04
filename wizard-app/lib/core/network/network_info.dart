/// Interface for checking network connectivity
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

