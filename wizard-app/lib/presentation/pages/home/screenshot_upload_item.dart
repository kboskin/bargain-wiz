/// Status of a single screenshot upload in Express Dealmaker.
enum ScreenshotUploadStatus {
  uploading,
  success,
  failed,
}

/// One screenshot with its upload state. Used for per-item upload UI and retry.
class ScreenshotUploadItem {
  const ScreenshotUploadItem({
    required this.path,
    this.status = ScreenshotUploadStatus.uploading,
  });

  final String path;
  final ScreenshotUploadStatus status;

  ScreenshotUploadItem copyWith({ScreenshotUploadStatus? status}) {
    return ScreenshotUploadItem(
      path: path,
      status: status ?? this.status,
    );
  }
}
