import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/deal_reply.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/upload_screenshot_result.dart';

/// Repository for Express Dealmaker: upload screenshots and fetch deal replies.
abstract class ExpressDealmakerRepository {
  /// Upload one screenshot. Returns [UploadScreenshotResult] on success.
  Future<Either<Failure, UploadScreenshotResult>> uploadScreenshot(String filePath);

  Future<Either<Failure, DealReply>> getDealReply({
    required List<String> uploadedIds,
    String? keyword,
    required String locale,
  });
}
