import 'dart:async';
import 'dart:math' as math;

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/upload_progress_screen_config.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// `data_upload` template ("Setting up"): pot Lottie, rotating status text with
/// `{platform}` / `{push}` placeholders, and a 220×6 gradient progress bar that
/// ramps to 100% over `progress_ramp_seconds`. Waits for [uploadFuture] (capped),
/// shows `done_text` for `done_hold_seconds`, then calls [onComplete].
class DataUploadScreenWidget extends StatefulWidget {
  const DataUploadScreenWidget({
    required this.config,
    required this.uploadFuture,
    required this.onComplete,
    super.key,
    this.isActivePage = true,
    this.placeholders = const {},
    this.textColor = WizColors.ink,
  });

  final UploadProgressScreenConfig config;
  final Future<void> uploadFuture;
  final VoidCallback onComplete;
  final bool isActivePage;
  final Map<String, String?> placeholders;
  final Color textColor;

  /// Extra time we are willing to wait for the upload after the ramp reaches 100%.
  static const Duration uploadGrace = Duration(seconds: 6);

  @override
  State<DataUploadScreenWidget> createState() => _DataUploadScreenWidgetState();
}

class _DataUploadScreenWidgetState extends State<DataUploadScreenWidget>
    with SingleTickerProviderStateMixin {
  late final AssetPathHelper _paths = di.sl<AssetPathHelper>();
  late final AnimationController _ramp = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: ((widget.config.progressRampSeconds ?? 5.0) * 1000).round().clamp(300, 120000)),
  );

  Timer? _textTimer;
  Timer? _capTimer;
  Timer? _holdTimer;
  int _textIndex = 0;
  bool _started = false;
  bool _uploadDone = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ramp
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _maybeFinish();
      });
    if (widget.isActivePage) _start();
  }

  @override
  void didUpdateWidget(DataUploadScreenWidget old) {
    super.didUpdateWidget(old);
    if (!_started && widget.isActivePage) _start();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _ramp.forward();

    final interval = Duration(milliseconds: (widget.config.textIntervalSeconds * 1000).round().clamp(300, 60000));
    _textTimer = Timer.periodic(interval, (_) {
      if (!mounted || _done) return;
      setState(() => _textIndex = math.min(_textIndex + 1, math.max(0, widget.config.texts.length - 1)));
    });

    widget.uploadFuture.then((_) => _onUploadSettled()).catchError((_) => _onUploadSettled());
    _capTimer = Timer((_ramp.duration ?? const Duration(seconds: 5)) + DataUploadScreenWidget.uploadGrace, () {
      if (mounted && !_done) _finish();
    });
  }

  void _onUploadSettled() {
    if (!mounted) return;
    _uploadDone = true;
    _maybeFinish();
  }

  void _maybeFinish() {
    if (_done || !mounted) return;
    if (_uploadDone && _ramp.isCompleted) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _textTimer?.cancel();
    _capTimer?.cancel();
    if (!_ramp.isCompleted) _ramp.value = 1;
    setState(() {});
    final hold = Duration(milliseconds: (widget.config.doneHoldSeconds * 1000).round().clamp(0, 10000));
    _holdTimer = Timer(hold, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _capTimer?.cancel();
    _holdTimer?.cancel();
    _ramp.dispose();
    super.dispose();
  }

  String _statusText(BuildContext context) {
    if (_done) {
      final done = TemplateText.resolve(context, widget.config.doneText, widget.placeholders);
      if (done.isNotEmpty) return done;
    }
    final texts = widget.config.texts;
    if (texts.isEmpty) return '';
    final i = _textIndex.clamp(0, texts.length - 1);
    return TemplateText.resolve(context, texts[i], widget.placeholders);
  }

  List<Color> _gradient() {
    final raw = widget.config.progressGradient ?? const [];
    final colors = raw.map(wizHexColor).whereType<Color>().toList();
    if (colors.length >= 2) return colors;
    return const [WizColors.purple, WizColors.teal];
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusText(context);
    final path = _paths.normalizeAssetPath(widget.config.lottieAsset);
    final isNetwork = _paths.isNetworkUrl(widget.config.lottieAsset);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: isNetwork
                ? Lottie.network(widget.config.lottieAsset, controller: _ramp, fit: BoxFit.contain)
                : Lottie.asset(path, controller: _ramp, fit: BoxFit.contain, frameRate: const FrameRate(60)),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280, minHeight: 52),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                status,
                key: ValueKey<String>(status),
                textAlign: TextAlign.center,
                style: WizType.status.copyWith(color: widget.textColor, height: 1.3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 220,
            height: 6,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: WizColors.inkTrack,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _ramp.value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: _gradient())),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
