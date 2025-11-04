import '../../core/network/network_info.dart';
import 'package:connectivity_plus/connectivity_plus.dart' as connectivity;

class NetworkInfoImpl implements NetworkInfo {
  final connectivity.Connectivity connectivityChecker;

  NetworkInfoImpl(this.connectivityChecker);

  @override
  Future<bool> get isConnected async {
    final result = await connectivityChecker.checkConnectivity();
    return !result.contains(connectivity.ConnectivityResult.none);
  }
}

