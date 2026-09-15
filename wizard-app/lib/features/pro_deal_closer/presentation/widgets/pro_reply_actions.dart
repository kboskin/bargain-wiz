import 'dart:async';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/conversation/domain/entities/deal_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text color of an intent tag.
Color proIntentColor(DealIntent intent) {
  switch (intent) {
    case DealIntent.opener:
      return WizColors.intentOpener;
    case DealIntent.counter:
      return WizColors.intentCounter;
    case DealIntent.close:
      return WizColors.intentClose;
    case DealIntent.other:
      return WizColors.textSecondary;
  }
}

/// "✨ Give me options" (34h ink pill) · "↻ Redo" (outlined pill) under a wizard reply.
class ProReplyActionRow extends StatelessWidget {
  const ProReplyActionRow({
    super.key,
    required this.optionsLabel,
    required this.redoLabel,
    this.loading = false,
    this.onOptions,
    this.onRedo,
  });

  final String optionsLabel;
  final String redoLabel;
  final bool loading;
  final VoidCallback? onOptions;
  final VoidCallback? onRedo;

  static const TextStyle _label = TextStyle(
    fontFamily: WizType.bodyFont,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          WizPressable(
            onTap: loading ? null : onOptions,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: WizColors.ink,
                borderRadius: BorderRadius.circular(17),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(opacity: loading ? 0 : 1, child: Text(optionsLabel, style: _label)),
                  if (loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          WizPressable(
            onTap: loading ? null : onRedo,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: WizColors.border, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(redoLabel, style: _label.copyWith(color: WizColors.ink)),
            ),
          ),
        ],
      );
}

/// Three copyable option rows, fading up with a 100 ms stagger.
class ProOptionRows extends StatelessWidget {
  const ProOptionRows({
    super.key,
    required this.options,
    required this.copiedToast,
    this.animate = true,
  });

  final List<DealLine> options;
  final String copiedToast;
  final bool animate;

  @override
  Widget build(BuildContext context) => StaggeredFadeUpColumn(
        stagger: WizMotion.chipStagger,
        gap: 6,
        enabled: animate,
        children: [
          for (final line in options) DealOptionRow(line: line, copiedToast: copiedToast),
        ],
      );
}

/// Radius 16 white row with 1.5 px border: intent tag · line · "⧉".
/// Tap copies; the row turns teal with "✓" for [WizMotion.copiedHold].
class DealOptionRow extends StatefulWidget {
  const DealOptionRow({super.key, required this.line, required this.copiedToast});

  final DealLine line;
  final String copiedToast;

  @override
  State<DealOptionRow> createState() => _DealOptionRowState();
}

class _DealOptionRowState extends State<DealOptionRow> {
  bool _copied = false;
  Timer? _revert;

  @override
  void dispose() {
    _revert?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.line.text));
    unawaited(HapticFeedback.lightImpact());
    if (!mounted) return;
    WizToast.show(context, widget.copiedToast);
    _revert?.cancel();
    setState(() => _copied = true);
    _revert = Timer(WizMotion.copiedHold, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => WizPressable(
        onTap: _copy,
        scale: 0.985,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: BoxDecoration(
            color: _copied ? WizColors.tealSoft : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _copied ? WizColors.teal : WizColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                widget.line.intent.label.toUpperCase(),
                style: WizType.intentTag.copyWith(color: proIntentColor(widget.line.intent)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.line.text, style: WizType.bodySmStrong)),
              const SizedBox(width: 10),
              Text(
                _copied ? '✓' : '⧉',
                style: const TextStyle(
                  fontFamily: WizType.bodyFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: WizColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
}
