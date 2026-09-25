import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_state.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/pro_attachment_bubble.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/pro_reply_actions.dart';
import 'package:flutter/material.dart';

/// Avatar (30) + gap (8): indent for wizard action rows / options.
const double kProWizardIndent = 38;

const BorderRadius _wizardRadius = BorderRadius.only(
  topLeft: Radius.circular(18),
  topRight: Radius.circular(18),
  bottomRight: Radius.circular(18),
  bottomLeft: Radius.circular(6),
);

const BorderRadius kProUserRadius = BorderRadius.only(
  topLeft: Radius.circular(18),
  topRight: Radius.circular(18),
  bottomRight: Radius.circular(6),
  bottomLeft: Radius.circular(18),
);

/// One row of the Pro Deal Closer list: wizard bubble (+ actions / options),
/// user text bubble or user attachment bubble. Fades up unless restored.
class ProMessageTile extends StatelessWidget {
  const ProMessageTile({
    super.key,
    required this.message,
    required this.readingLabel,
    required this.optionsLabel,
    required this.redoLabel,
    required this.copiedToast,
    this.onOptions,
    this.onRedo,
  });

  final ProChatMessage message;
  final String readingLabel;
  final String optionsLabel;
  final String redoLabel;
  final String copiedToast;
  final VoidCallback? onOptions;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.92;
    final Widget body;
    if (message.isWizard) {
      body = _WizardMessage(
        message: message,
        maxWidth: maxWidth,
        optionsLabel: optionsLabel,
        redoLabel: redoLabel,
        copiedToast: copiedToast,
        onOptions: onOptions,
        onRedo: onRedo,
      );
    } else {
      // One turn can carry screenshots and text together: the screenshots first, the text
      // under them — the order the wizard reads them in.
      body = Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.hasAttachments)
                ProAttachmentBubble(
                  paths: message.attachmentPaths,
                  isUploading: message.isUploading,
                  readingLabel: readingLabel,
                ),
              if (message.hasAttachments && message.text.isNotEmpty) const SizedBox(height: 6),
              if (message.text.isNotEmpty || !message.hasAttachments) UserTextBubble(text: message.text),
            ],
          ),
        ),
      );
    }
    return FadeUp(
      enabled: !message.restored,
      duration: const Duration(milliseconds: 300),
      child: body,
    );
  }
}

class _WizardMessage extends StatelessWidget {
  const _WizardMessage({
    required this.message,
    required this.maxWidth,
    required this.optionsLabel,
    required this.redoLabel,
    required this.copiedToast,
    this.onOptions,
    this.onRedo,
  });

  final ProChatMessage message;
  final double maxWidth;
  final String optionsLabel;
  final String redoLabel;
  final String copiedToast;
  final VoidCallback? onOptions;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const WizAvatar(),
              const SizedBox(width: 8),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth - kProWizardIndent),
                  child: WizardBubble(text: message.text),
                ),
              ),
            ],
          ),
          if (message.showActions || message.optionsLoading) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: kProWizardIndent),
              child: ProReplyActionRow(
                optionsLabel: optionsLabel,
                redoLabel: redoLabel,
                loading: message.optionsLoading,
                onOptions: onOptions,
                onRedo: onRedo,
              ),
            ),
          ],
          if (message.options.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: kProWizardIndent),
              child: ProOptionRows(
                options: message.options,
                copiedToast: copiedToast,
                animate: !message.restored,
              ),
            ),
          ],
        ],
      );
}

/// White wizard bubble, radius 18/18/18/6, Figtree 15, soft card shadow.
class WizardBubble extends StatelessWidget {
  const WizardBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: _wizardRadius,
          boxShadow: WizShadows.cardSoft,
        ),
        child: Text(text, style: WizType.chat),
      );
}

/// Ink user bubble, radius 18/18/6/18, white Figtree 15.
class UserTextBubble extends StatelessWidget {
  const UserTextBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: const BoxDecoration(
          color: WizColors.ink,
          borderRadius: kProUserRadius,
          boxShadow: WizShadows.cardSoft,
        ),
        child: Text(text, style: WizType.chat.copyWith(color: Colors.white)),
      );
}

/// Avatar + white bubble with three blinking purple dots.
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) => FadeUp(
        duration: const Duration(milliseconds: 300),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const WizAvatar(),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: _wizardRadius,
                boxShadow: WizShadows.cardSoft,
              ),
              child: const TypingDots(),
            ),
          ],
        ),
      );
}
