import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/deal_reply.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/upload_screenshot_result.dart';

/// Repository for Express Dealmaker: upload screenshots and fetch deal replies.
abstract class ExpressDealmakerRepository {
  /// Upload one screenshot. Returns [UploadScreenshotResult] on success.
  Future<Either<Failure, UploadScreenshotResult>> uploadScreenshot(final String filePath);

  /// Lines for the uploaded screenshots, focused by [keyword] and written in the [vibe] tone.
  /// With [conversationId] the existing backend deal is regenerated instead of a new one.
  Future<Either<Failure, DealReply>> getDealReply({
    required final List<String> uploadedIds,
    required final String locale,
    final String? keyword,
    final String? vibe,
    final String? conversationId,
  });
}
