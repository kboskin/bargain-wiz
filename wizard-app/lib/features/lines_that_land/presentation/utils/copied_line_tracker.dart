import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';

/// Remembers which line was just copied so its row can show the teal "copied" state,
/// and reverts after [hold] (1.2 s from the handoff). Only one line is "copied" at a time.
class CopiedLineTracker extends ChangeNotifier {
  CopiedLineTracker({
    this.hold = WizMotion.copiedHold,
    Timer Function(Duration, void Function())? scheduler,
  }) : _schedule = scheduler ?? Timer.new;

  final Duration hold;
  final Timer Function(Duration, void Function()) _schedule;
  Timer? _timer;
  String? _key;

  /// Key of the line currently highlighted, if any.
  String? get copiedKey => _key;

  bool isCopied(String key) => _key == key;

  /// Stable key for a line: category id + index (`"opening#1"`).
  static String keyFor(String categoryId, int index) => '$categoryId#$index';

  /// Highlights [key] and schedules the revert. Re-copying restarts the hold.
  void markCopied(String key) {
    _timer?.cancel();
    _key = key;
    notifyListeners();
    _timer = _schedule(hold, () {
      if (_key == key) {
        _key = null;
        notifyListeners();
      }
    });
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    if (_key != null) {
      _key = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Copy [text] to the clipboard with the handoff feedback: light haptic,
/// teal row state via [tracker], ink toast "Copied to clipboard".
Future<void> copyLineToClipboard(
  BuildContext context,
  CopiedLineTracker tracker, {
  required String text,
  required String key,
  String toast = 'Copied to clipboard',
}) async {
  tracker.markCopied(key);
  HapticFeedback.lightImpact();
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) WizToast.show(context, toast);
}
