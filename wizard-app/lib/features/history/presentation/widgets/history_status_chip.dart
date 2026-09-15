import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_labels.dart';

/// Open (ink 8% / ink) · Won (green 16% / #067A55) · Lost (red 12% / #B42323), Figtree 11/600.
class HistoryStatusChip extends StatelessWidget {
  const HistoryStatusChip({super.key, required this.status});

  final ConversationStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = ConversationLabels.statusColors(status);
    return WizTag(
      label: ConversationLabels.statusLabel(context, status),
      color: bg,
      textColor: fg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      style: WizType.chipSm,
    );
  }
}
