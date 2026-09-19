/// What the screenshot pipeline produces before anything is sent.
///
/// The client owns this: [ScreenshotEncoder] downscales every screenshot to
/// [maxImageBytes] or less, and the AI flows send at most [maxImages] of them. The
/// function's MAX_IMAGES / MAX_IMAGE_BYTES / MAX_TOTAL_IMAGE_BYTES params sit well
/// above these numbers — they are a sanity ceiling against a tampered client, not a
/// contract the app has to hit exactly.
class AttachmentLimits {
  AttachmentLimits._();

  /// Screenshots per request. The backend replays at most this many stored
  /// screenshots into a later prompt, newest first.
  static const int maxImages = 10;

  /// Bytes per screenshot after downscaling (1.5 MB). A 1280px q80 screenshot is
  /// 200-400 KB, so this is the ceiling the pipeline shrinks towards, not the norm.
  static const int maxImageBytes = 1500000;
}
