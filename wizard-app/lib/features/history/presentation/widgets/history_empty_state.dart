import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/history/presentation/history_copy.dart';

/// Mascot 110 @ 85% + "No deals yet" (or "Nothing matches" while filtering).
class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({super.key, this.filtered = false});

  /// True when rows exist but the search / filter hides them all.
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final title = HistoryCopy.of(
      context,
      filtered ? HistoryCopy.nothingMatchesTitle : HistoryCopy.emptyTitle,
    );
    final body = HistoryCopy.of(
      context,
      filtered ? HistoryCopy.nothingMatchesBody : HistoryCopy.emptyBody,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WizMascot(width: 110, opacity: 0.85),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: WizType.sectionTitle),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: WizType.bodySm),
        ],
      ),
    );
  }
}
