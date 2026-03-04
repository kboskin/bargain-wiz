import 'package:equatable/equatable.dart';

/// Result of uploading a single screenshot. [id] is optional server-assigned id.
class UploadScreenshotResult extends Equatable {
  const UploadScreenshotResult({this.id});

  final String? id;

  @override
  List<Object?> get props => [id];
}
