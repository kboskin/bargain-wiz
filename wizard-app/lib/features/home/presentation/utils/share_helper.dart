import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/home/data/models/refer_config.dart';
import 'package:appwizard/features/home/data/models/share_config.dart';
import 'package:appwizard/features/home/presentation/utils/share_message.dart';

/// Native share sheet helpers (ported from the legacy home page).
class ShareHelper {
  ShareHelper._();

  /// Joins non-empty parts with blank lines: title, description, link.
  static String composeMessage({String? title, String? description, String? link}) =>
      composeShareMessage(title: title, description: description, link: link);

  /// App bar "Share" pill: shares `share_config` (title, description, link).
  static Future<void> shareApp(BuildContext context) async {
    final config = di.sl<RemoteConfigService>().getShareConfig() ?? ShareConfig.defaultConfig;
    final title = config.getTitle(context).trim();
    final text = composeMessage(
      title: title,
      description: config.getDescription(context),
      link: config.linkUrl,
    );
    if (text.isEmpty) {
      WizToast.show(context, 'Nothing to share');
      return;
    }
    await Share.share(text, subject: title.isNotEmpty ? title : null);
  }

  /// Refer sheet CTA: shares the referral copy from `refer_config`, falling back to [shareApp].
  static Future<void> shareRefer(BuildContext context, ReferConfig? referConfig) async {
    if (referConfig != null) {
      final title = referConfig.getShareTitle(context).trim();
      final text = composeMessage(
        title: title,
        description: referConfig.getShareDescription(context),
        link: referConfig.shareLinkUrl,
      );
      if (text.isNotEmpty) {
        await Share.share(text, subject: title.isNotEmpty ? title : null);
        return;
      }
    }
    if (context.mounted) await shareApp(context);
  }
}
