import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/express_dealmaker/presentation/express_copy.dart';

/// 5c Error: greyed mascot, "The spell fizzled", body copy and a bottom
/// "🔄 Retry" primary button.
class ExpressErrorStage extends StatelessWidget {
  const ExpressErrorStage({
    required this.copy,
    required this.onRetry,
    super.key,
  });

  final ExpressCopy copy;
  final VoidCallback onRetry;

  @override
  Widget build(final BuildContext context) {
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 20.0);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WizMascot(width: 110, greyscale: true, opacity: 0.8),
                  const SizedBox(height: WizSpacing.stackLg),
                  Text(copy.errorTitle, textAlign: TextAlign.center, style: WizType.titleSm),
                  const SizedBox(height: WizSpacing.stackLg),
                  Text(copy.errorBody, textAlign: TextAlign.center, style: WizType.bodyMd),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(WizSpacing.gutter, 0, WizSpacing.gutter, bottom),
          child: WizPrimaryButton(label: '🔄 ${copy.retry}', onPressed: onRetry),
        ),
      ],
    );
  }
}
