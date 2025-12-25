/// Base interface for data sources
/// T - Entity type
abstract class DataSource<T> {
  Future<T> getData();
}

/// Remote data source interface
abstract class RemoteDataSource {
  // Define remote data source methods here
}

/// Local data source interface
abstract class LocalDataSource {
  // Define local data source methods here
}

