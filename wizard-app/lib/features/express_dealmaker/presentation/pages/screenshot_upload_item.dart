import 'package:equatable/equatable.dart';

/// Status of a single screenshot upload in Express Dealmaker.
enum ScreenshotUploadStatus {
  uploading,
  success,
  failed,
}

/// One screenshot with its upload state. Used for per-item upload UI and retry.
class ScreenshotUploadItem extends Equatable {
  const ScreenshotUploadItem({
    required this.path,
    this.status = ScreenshotUploadStatus.uploading,
    this.uploadedId,
  });

  /// Local file path of the screenshot.
  final String path;
  final ScreenshotUploadStatus status;

  /// Server-assigned id after a successful upload. Falls back to [path] when
  /// the conversation was restored from history (ids are not persisted).
  final String? uploadedId;

  bool get isUploading => status == ScreenshotUploadStatus.uploading;
  bool get isSuccess => status == ScreenshotUploadStatus.success;
  bool get isFailed => status == ScreenshotUploadStatus.failed;

  /// Id to send to the reply endpoint for a successfully uploaded item.
  String get effectiveId => uploadedId ?? path;

  ScreenshotUploadItem copyWith({
    final ScreenshotUploadStatus? status,
    final String? uploadedId,
  }) =>
      ScreenshotUploadItem(
        path: path,
        status: status ?? this.status,
        uploadedId: uploadedId ?? this.uploadedId,
      );

  @override
  List<Object?> get props => [path, status, uploadedId];
}
