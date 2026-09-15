import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/core/widgets/wiz/wiz_sheet.dart';
import 'package:appwizard/core/widgets/wiz/wiz_text_field.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_labels.dart';
import 'package:appwizard/features/history/presentation/history_copy.dart';

/// Result of [HistoryStatusSheet]: chosen status and optional final price.
class HistoryStatusResult {
  const HistoryStatusResult({required this.status, this.priceAfter});

  final ConversationStatus status;
  final String? priceAfter;
}

/// Long-press sheet: set Open / Won / Lost and optionally enter the final price.
class HistoryStatusSheet extends StatefulWidget {
  const HistoryStatusSheet({super.key, required this.conversation});

  final Conversation conversation;

  static Future<HistoryStatusResult?> show(BuildContext context, Conversation conversation) =>
      WizSheet.show<HistoryStatusResult>(
        context,
        builder: (_) => HistoryStatusSheet(conversation: conversation),
      );

  @override
  State<HistoryStatusSheet> createState() => _HistoryStatusSheetState();
}

class _HistoryStatusSheetState extends State<HistoryStatusSheet> {
  late ConversationStatus _status = widget.conversation.status;
  late final TextEditingController _price =
      TextEditingController(text: widget.conversation.priceAfter ?? '');

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final price = _price.text.trim();
    Navigator.of(context).pop(
      HistoryStatusResult(status: _status, priceAfter: price.isEmpty ? null : price),
    );
  }

  @override
  Widget build(BuildContext context) => WizSheet(
        title: HistoryCopy.of(context, HistoryCopy.statusSheetTitle),
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ConversationLabels.title(context, widget.conversation),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WizType.bodySm,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in ConversationStatus.values)
                  WizChip(
                    label: ConversationLabels.statusLabel(context, s),
                    selected: _status == s,
                    onTap: () => setState(() => _status = s),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              HistoryCopy.of(context, HistoryCopy.finalPrice),
              style: WizType.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            WizTextField(
              controller: _price,
              height: 52,
              hintText: HistoryCopy.of(context, HistoryCopy.finalPriceHint),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            WizPrimaryButton(
              label: HistoryCopy.of(context, HistoryCopy.save),
              onPressed: _save,
            ),
          ],
        ),
      );
}
