import 'package:flutter/widgets.dart';

import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/home/data/models/main_page_config.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// All remote-configured copy used by the Express Dealmaker screen, resolved
/// for the current locale with English fallbacks (keys: `main_page_config.express_*`
/// and `reply_*`).
class ExpressCopy {
  const ExpressCopy({
    required this.headerTitle,
    required this.pickTitle,
    required this.pickDescription,
    required this.dropzone,
    required this.dropzoneSub,
    required this.uploadingStatus,
    required this.seeingPrefix,
    required this.errorTitle,
    required this.errorBody,
    required this.keywordHint,
    required this.tapReplyHint,
    required this.whyLabel,
    required this.hideLabel,
    required this.dislikeToast,
    required this.copiedToast,
    required this.retry,
    required this.getMore,
    required this.addScreenshot,
    required this.pickCta,
  });

  /// Resolves every string from [config] (falling back to l10n / English).
  factory ExpressCopy.resolve(final BuildContext context, final MainPageConfig? config) {
    final l10n = AppLocalizations.of(context);
    String t(final dynamic source, final String fallback) =>
        TemplateText.textOf(context, source, fallback: fallback);
    return ExpressCopy(
      headerTitle: _stripLeadingSymbols(
        t(config?.primaryCtaButton, l10n?.simpleModeTitle ?? 'Express Dealmaker'),
      ),
      pickTitle: t(config?.expressPickTitle, 'Drop the listing or the chat'),
      pickDescription: t(
        config?.expressPickDescription,
        "Screenshots of the item, the price and the seller's last message work best.",
      ),
      dropzone: t(config?.expressPickDropzone, l10n?.simpleModeDropHint ?? 'Drop a screenshot'),
      dropzoneSub: t(config?.expressPickDropzoneSub, 'Choose from your photos'),
      uploadingStatus: t(config?.expressUploadingStatus, 'Reading the listing…'),
      seeingPrefix: t(config?.expressSeeingPrefix, '${l10n?.simpleModeSeeing ?? 'Seeing'}:'),
      errorTitle: t(config?.expressErrorTitle, 'The spell fizzled'),
      errorBody: t(
        config?.expressErrorBody,
        "We couldn't read your screenshots. Check your connection and try again — nothing was lost.",
      ),
      keywordHint: t(
        config?.expressDealmakerKeywordHint,
        l10n?.expressDealmakerKeywordHint ?? 'Give us a word or two to focus on',
      ),
      tapReplyHint: t(
        config?.expressDealmakerTapReplyHint,
        l10n?.tapReplyToCopy ?? 'tap a reply to copy',
      ),
      whyLabel: t(config?.replyWhyLabel, 'Why this works'),
      hideLabel: t(config?.replyHideLabel, 'Hide'),
      dislikeToast: t(config?.replyDislikeToast, "Thanks — we'll tune the wizard"),
      copiedToast: 'Copied to clipboard',
      retry: l10n?.retry ?? 'Retry',
      getMore: l10n?.getMore ?? 'Get More',
      addScreenshot: l10n?.simpleModeAddScreenshot ?? 'Add screenshot',
      pickCta: (final int n) =>
          config?.expressPickCta?.get(context, n) ??
          (n == 1 ? 'Read 1 screenshot' : 'Read $n screenshots'),
    );
  }

  final String headerTitle;
  final String pickTitle;
  final String pickDescription;
  final String dropzone;
  final String dropzoneSub;
  final String uploadingStatus;
  final String seeingPrefix;
  final String errorTitle;
  final String errorBody;
  final String keywordHint;
  final String tapReplyHint;
  final String whyLabel;
  final String hideLabel;
  final String dislikeToast;
  final String copiedToast;
  final String retry;
  final String getMore;
  final String addScreenshot;
  /// Plural CTA label for the pick stage, e.g. "Read 2 screenshots".
  final String Function(int count) pickCta;

  /// The home CTA copy may start with an emoji ("📷 Express Dealmaker"); the
  /// header shows the bare title.
  static String _stripLeadingSymbols(final String value) {
    final stripped = value.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');
    return stripped.isEmpty ? value : stripped;
  }
}
