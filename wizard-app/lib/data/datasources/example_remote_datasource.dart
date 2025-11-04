import '../models/example_model.dart';
import 'datasource.dart';
import '../../core/error/exceptions.dart';

/// Example remote data source implementation
class ExampleRemoteDataSource implements RemoteDataSource, DataSource<ExampleModel> {
  // In a real implementation, you would inject Dio or another HTTP client here
  // final Dio httpClient;

  @override
  Future<ExampleModel> getData() async {
    // Example implementation - replace with actual API call
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      // In real implementation:
      // final response = await httpClient.get('/api/example');
      // return ExampleModel.fromJson(response.data);
      
      // For now, return mock data
      return ExampleModel(
        id: '1',
        name: 'Example from Remote',
      );
    } catch (e) {
      throw ServerException('Failed to fetch data from server: $e');
    }
  }
}

