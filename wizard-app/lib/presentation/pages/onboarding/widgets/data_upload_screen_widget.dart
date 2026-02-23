import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:appwizard/data/models/remote_config/upload_progress_screen_config.dart';

/// Screen that shows upload progress, segment-based text, and a Lottie animation
/// whose progress is tied to the progress bar. Progress ramps 0→90% over config
/// time; the last 10% (90%→100%) always animates over 2 seconds when upload completes.
class DataUploadScreenWidget extends StatefulWidget {
  const DataUploadScreenWidget({
    super.key,
    required this.config,
    required this.uploadFuture,
    required this.onComplete,
    this.isActivePage = true,
    this.highlightWordsData,
    this.highlightColor,
  });

  final UploadProgressScreenConfig config;
  final Future<void> uploadFuture;
  final VoidCallback onComplete;
  final bool isActivePage;
  /// Optional highlight words for segment text (same format as other onboarding screens).
  final dynamic highlightWordsData;
  /// Optional highlight color (e.g. from metadata.highlight_color).
  final Color? highlightColor;

  @override
  State<DataUploadScreenWidget> createState() => _DataUploadScreenWidgetState();
}

class _DataUploadScreenWidgetState extends State<DataUploadScreenWidget>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  Timer? _rampTimer;
  late final AssetPathHelper _assetPathHelper;
  late final ColorHelper _colorHelper;
  late final TextHighlightHelper _textHighlightHelper;
  AnimationController? _lottieController;
  AnimationController? _finalRampController;
  bool _uploadDone = false;
  bool _minTimeElapsed = false;
  bool _timersStarted = false;
  bool _finalRampStarted = false;
  static const int _rampTickMs = 50;
  static const double _maxProgressBeforeComplete = 0.9;
  static const double _defaultRampSeconds = 5.0;
  static const Duration _minDisplayTime = Duration(milliseconds: 1500);
  /// Last 10% (90%→100%) always animates over this duration.
  static const Duration _finalRampDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _assetPathHelper = di.sl<AssetPathHelper>();
    _colorHelper = di.sl<ColorHelper>();
    _textHighlightHelper = TextHighlightHelper(_colorHelper);
    if (widget.isActivePage) _startTimers();
  }

  @override
  void didUpdateWidget(DataUploadScreenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_timersStarted && widget.isActivePage) _startTimers();
  }

  void _startTimers() {
    if (_timersStarted) return;
    _timersStarted = true;
    _startProgressRamp();
    Future.delayed(_minDisplayTime, () {
      if (!mounted) return;
      setState(() => _minTimeElapsed = true);
    });
    widget.uploadFuture.then((_) {
      if (!mounted) return;
      setState(() => _uploadDone = true);
      _startFinalRampIfReady();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _uploadDone = true);
      _startFinalRampIfReady();
    });
  }

  /// When upload is done, animate the last 10% (90%→100%) over 2 seconds, then complete.
  void _startFinalRampIfReady() {
    if (!_uploadDone || _finalRampStarted || !mounted) return;
    _finalRampStarted = true;
    _rampTimer?.cancel();
    final startProgress = _progress.clamp(0.0, _maxProgressBeforeComplete);
    _finalRampController?.dispose();
    _finalRampController = AnimationController(
      vsync: this,
      duration: _finalRampDuration,
    );
    _finalRampController!.addListener(() {
      if (!mounted) return;
      final t = _finalRampController!.value;
      setState(() {
        _progress = startProgress + (1.0 - startProgress) * t;
        _syncLottieProgress();
      });
    });
    _finalRampController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _finalRampController?.dispose();
        _finalRampController = null;
        _onUploadComplete();
      }
    });
    _finalRampController!.forward();
  }

  void _startProgressRamp() {
    // Remote config: config.progressRampSeconds (linear ramp duration)
    final rampSeconds =
        widget.config.progressRampSeconds ?? _defaultRampSeconds;
    if (rampSeconds <= 0) return;
    final totalTicks = (rampSeconds * 1000 / _rampTickMs).ceil();
    int tick = 0;
    _rampTimer = Timer.periodic(
      const Duration(milliseconds: _rampTickMs),
      (_) {
        if (!mounted) return;
        tick++;
        final p = (tick / totalTicks).clamp(0.0, 1.0) * _maxProgressBeforeComplete;
        setState(() {
          _progress = p;
          _syncLottieProgress();
        });
        if (tick >= totalTicks) _rampTimer?.cancel();
      },
    );
  }

  /// Text index from progress segments: each text covers 1/n of the progress.
  int _segmentTextIndex(int textCount) {
    if (textCount <= 0) return 0;
    final index = (_progress * textCount).floor();
    return index.clamp(0, textCount - 1);
  }

  void _onUploadComplete() {
    _rampTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _syncLottieProgress();
    });
    // 1s delay at 100% before completing the whole animation
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) widget.onComplete();
    });
  }

  /// Keeps Lottie frame in sync with _progress (same value drives percent and circular progress).
  void _syncLottieProgress() {
    final c = _lottieController;
    if (c != null) c.value = _progress.clamp(0.0, 1.0);
  }

  /// Build rich text for segment label with highlighted words (same as engagement/select).
  /// Supports isHighlight (color), isBold ("bold"), isBoldLarge ("bold_large").
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    dynamic highlightWordsData,
  ) {
    const double bodySize = 18.0;
    const double boldLargeSize = 22.0;
    final defaultHighlightColor = widget.highlightColor;
    final config = _textHighlightHelper.parseHighlightWords(highlightWordsData);
    final textSpans = <TextSpan>[];
    final parts = description.split(' ');

    for (final word in parts) {
      final result = _textHighlightHelper.processWord(
        word,
        config,
        defaultHighlightColor,
      );
      final useBold = result.isHighlight || result.isBold || result.isBoldLarge;
      final color = useBold
          ? (result.wordColor ?? defaultHighlightColor ?? AppColors.backgroundDark)
          : AppColors.backgroundDark.withValues(alpha: 0.9);
      final fontSize = result.isBoldLarge
          ? boldLargeSize
          : (result.isHighlight || result.isBold ? 20.0 : bodySize);

      textSpans.add(
        TextSpan(
          text: '$word ',
          style: useBold
              ? TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  height: 1.5,
                )
              : Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  height: 1.5,
                  fontSize: bodySize,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }

  @override
  void dispose() {
    _rampTimer?.cancel();
    _finalRampController?.dispose();
    _lottieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remote config: config.texts (segment-based; each segment shows one message)
    final texts = widget.config.texts;
    final segmentIndex = _segmentTextIndex(texts.length);
    final displayText = texts.isNotEmpty && segmentIndex < texts.length
        ? (texts[segmentIndex] is MultilocaleText
            ? (texts[segmentIndex] as MultilocaleText).get(context)
            : texts[segmentIndex].toString())
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLottie(context),
          const SizedBox(height: 32),
          if (displayText.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: StyledDescriptionWidget(
                key: ValueKey<int>(segmentIndex),
                description: displayText,
                highlightWordsData: widget.highlightWordsData,
                highlightColor: widget.highlightColor,
                textHighlightHelper: _textHighlightHelper,
                onRichTextDescription: _buildRichTextDescription,
              ),
            ),
          const SizedBox(height: 24),
          // Percentage label: same source as Lottie and circular progress (_progress) so all stay in sync
          Text(
            _progress >= 1.0
                ? '100%'
                : '${(_progress.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.backgroundDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Circular progress: value = _progress (synced with Lottie and percent above)
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: _progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.backgroundDark,
              ),
              strokeWidth: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLottie(BuildContext context) {
    final path = _assetPathHelper.normalizeAssetPath(widget.config.lottieAsset);
    final isNetwork = _assetPathHelper.isNetworkUrl(widget.config.lottieAsset);

    if (_lottieController == null) {
      _lottieController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      );
      _lottieController!.value = 0.0;
    }

    final child = isNetwork
        ? Lottie.network(
            widget.config.lottieAsset,
            controller: _lottieController,
            fit: BoxFit.contain,
            frameRate: const FrameRate(60),
            options: LottieOptions(enableMergePaths: true),
            onLoaded: (composition) {
              _lottieController?.duration = composition.duration;
              _syncLottieProgress();
            },
          )
        : Lottie.asset(
            path,
            controller: _lottieController,
            fit: BoxFit.contain,
            frameRate: const FrameRate(60),
            options: LottieOptions(enableMergePaths: true),
            onLoaded: (composition) {
              _lottieController?.duration = composition.duration;
              _syncLottieProgress();
            },
          );

    return SizedBox(
      width: 240,
      height: 240,
      child: child,
    );
  }
}
