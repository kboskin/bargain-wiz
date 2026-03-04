import 'package:appwizard/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/domain/entities/upload_screenshot_result.dart';
import 'package:appwizard/domain/entities/deal_reply.dart';

/// Maps Express Dealmaker DTOs to domain entities.
class UploadScreenshotResultMapper {
  UploadScreenshotResult toEntity(UploadScreenshotResultDto dto) {
    return UploadScreenshotResult(id: dto.id);
  }
}

/// Maps deal reply DTO to domain entity.
class DealReplyMapper {
  DealReply toEntity(DealReplyDto dto) {
    return DealReply(options: dto.options);
  }
}
