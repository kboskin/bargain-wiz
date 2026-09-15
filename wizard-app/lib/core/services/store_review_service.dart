import 'package:in_app_review/in_app_review.dart';

/// Native store review prompt (App Store / Google Play).
///
/// Safe to call from anywhere: returns false instead of throwing when the store is not
/// available (emulator, sideloaded build, tests), so callers can simply continue.
class StoreReview {
  StoreReview._();

  static Future<bool> request() async {
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return false;
      await review.requestReview();
      return true;
    } on Object {
      return false;
    }
  }
}
