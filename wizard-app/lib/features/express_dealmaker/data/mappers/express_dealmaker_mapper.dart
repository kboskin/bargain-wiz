import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/deal_reply.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/upload_screenshot_result.dart';

/// Maps Express Dealmaker DTOs to domain entities.
class UploadScreenshotResultMapper {
  UploadScreenshotResult toEntity(final UploadScreenshotResultDto dto) =>
      UploadScreenshotResult(id: dto.id);
}

/// Maps deal reply DTO to domain entity (intent strings → [DealIntent]).
class DealReplyMapper {
  DealReply toEntity(final DealReplyDto dto) => DealReply(
        seeing: dto.seeing,
        conversationId: dto.conversationId,
        lines: dto.lines.map(toLine).toList(),
      );

  DealLine toLine(final DealLineDto dto) => DealLine(
        text: dto.text,
        intent: DealIntent.fromString(dto.intent),
        why: dto.why,
      );
}
