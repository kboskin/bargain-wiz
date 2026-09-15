import 'package:appwizard/features/conversation/domain/entities/deal_line.dart';
import 'package:appwizard/features/pro_deal_closer/data/datasources/pro_deal_closer_remote_datasource.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/wizard_reply.dart';

/// Maps [WizardReplyDto] to the domain [WizardReply].
class WizardReplyMapper {
  WizardReply toEntity(WizardReplyDto dto) => WizardReply(text: dto.text);
}

/// Maps option DTOs to domain [DealLine]s.
class DealOptionsMapper {
  DealLine toEntity(DealOptionDto dto) => DealLine(
        text: dto.text,
        intent: DealIntent.fromString(dto.intent),
        why: dto.why,
      );

  List<DealLine> toEntities(List<DealOptionDto> dtos) => dtos.map(toEntity).toList();
}
