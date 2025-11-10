/// Utility class for handling asset path normalization and URL detection
class AssetPathHelper {
  /// Checks if the given path is a network URL (http:// or https://)
  bool isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Checks if the given path is already a full asset path (starts with 'assets/')
  bool isAssetPath(String path) {
    return path.startsWith('assets/');
  }

  /// Normalizes an asset path by adding 'assets/' prefix if needed
  /// Returns the original path if it's a network URL or already has 'assets/' prefix
  /// Otherwise, prepends 'assets/' to the path
  String normalizeAssetPath(String path) {
    // Don't modify network URLs
    if (isNetworkUrl(path)) {
      return path;
    }

    // Don't modify paths that already start with 'assets/'
    if (isAssetPath(path)) {
      return path;
    }

    // Add 'assets/' prefix for relative paths
    return 'assets/$path';
  }
}

