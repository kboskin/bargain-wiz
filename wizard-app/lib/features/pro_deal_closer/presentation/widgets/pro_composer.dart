import 'dart:async';
import 'dart:math' as math;

import 'package:appwizard/core/config/attachment_limits.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/speech_locale.dart';
import 'package:appwizard/core/widgets/attachment_image.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_text_field.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Pro Deal Closer composer: "+" (attach) · text field · press-and-hold mic · send (↑).
/// Sits at the bottom of the screen over a fade from transparent to the app teal tint.
///
/// A turn is whatever the composer holds when Send is tapped: picked screenshots are staged
/// in a strip above the field (removable, up to [AttachmentLimits.maxImages]) and go out
/// together with the typed text, either of which may be empty. Nothing is sent on pick.
class ProComposer extends StatefulWidget {
  const ProComposer({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.enabled = true,
    this.showMic = true,
    this.hintText = 'Type a line...',
    this.speechUnavailableText = 'Speech recognition is not available on this device',
    this.removeScreenshotLabel = 'Remove screenshot',
    this.screenshotLimitText = 'Up to ${AttachmentLimits.maxImages} screenshots per message',
    this.bottomPadding = WizSpacing.homeIndicator,
  });

  /// The typed text (trimmed) and the staged screenshot paths, in the order picked.
  final void Function(String text, List<String> paths) onSend;
  /// Opens the picker; resolves to the picked file paths (empty when cancelled).
  final Future<List<String>> Function() onAttach;
  /// False while the wizard is answering: the draft stays, Send waits.
  final bool enabled;
  final bool showMic;
  final String hintText;
  final String speechUnavailableText;
  final String removeScreenshotLabel;
  final String screenshotLimitText;
  /// Bottom inset below the row (34 + safe area, or less when the keyboard is up).
  final double bottomPadding;

  @override
  State<ProComposer> createState() => _ProComposerState();
}

class _ProComposerState extends State<ProComposer> {
  /// Failed `listen()` starts tolerated per hold before we surface the toast.
  static const int _maxStartFailures = 3;

  /// Errors no amount of retrying fixes: the recognizer itself is unusable, so
  /// restarting just loops in silence. iOS Simulators report
  /// `error_assets_not_installed` because they ship no speech model.
  static const Set<String> _fatalSpeechErrors = {
    'error_assets_not_installed',
    'error_speech_recognizer_disabled',
    'error_speech_recognizer_request_not_authorized',
  };

  /// Head start the OS audio unit needs to tear down before a new session.
  static const Duration _micReleaseDelay = Duration(milliseconds: 120);

  /// Longest the first hold waits for the recognizer's locale list.
  static const Duration _localeLookupTimeout = Duration(milliseconds: 600);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  /// Screenshots picked for the next turn, not sent yet.
  final List<String> _staged = [];
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isPointerDown = false;

  /// Recognizer locale matched to the device languages, resolved once after
  /// `initialize()`. Null means no match — the plugin picks for itself.
  String? _localeId;

  /// The plugin is not re-entrant. Its native `listen` checks "am I already
  /// listening?" and only sets the flag much later, so two overlapping calls
  /// both pass, each build an `AVAudioEngine` over the same field, and the
  /// loser reads a freed input node — a SIGSEGV in `AVAudioNode.inputFormat`
  /// on iOS. Every call to `_speech` is chained here so only one is in flight.
  Future<void> _micQueue = Future<void>.value();

  /// Set while an end-of-session restart is already queued. One pause reaches
  /// us as `notListening`, an error *and* `done`; without this each of the
  /// three would start its own session.
  bool _restartQueued = false;

  /// Consecutive `error_listen_failed` reports; reset by any other outcome.
  int _startFailures = 0;

  /// Text already in the field when the mic was pressed; recognition appends after it.
  String _baseText = '';

  @override
  void dispose() {
    _isPointerDown = false;
    unawaited(_enqueue(_speech.cancel));
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Runs [action] once every mic call queued before it has settled. Failures
  /// are absorbed so one bad session cannot poison the chain.
  Future<void> _enqueue(Future<void> Function() action) {
    final queued = _micQueue.then((_) => action()).catchError(_onMicCallFailed);
    _micQueue = queued;
    return queued;
  }

  /// A plugin call threw — `listen()` raises `ListenFailedException` when the
  /// platform side refuses outright. Drop out of dictation rather than retry.
  void _onMicCallFailed(Object error) {
    _isPointerDown = false;
    _restartQueued = false;
    if (!mounted) return;
    setState(() => _isListening = false);
    WizToast.show(context, widget.speechUnavailableText);
  }

  bool get _canSend => widget.enabled && (_controller.text.trim().isNotEmpty || _staged.isNotEmpty);

  Future<void> _attach() async {
    final picked = await widget.onAttach();
    if (!mounted || picked.isEmpty) return;
    final room = AttachmentLimits.maxImages - _staged.length;
    setState(() => _staged.addAll(picked.take(room)));
    if (picked.length > room) WizToast.show(context, widget.screenshotLimitText);
  }

  void _send() {
    if (!_canSend) return;
    final text = _controller.text.trim();
    final paths = List<String>.of(_staged);
    _isPointerDown = false;
    if (_isListening) {
      setState(() => _isListening = false);
      unawaited(_enqueue(_speech.stop));
    }
    _controller.clear();
    setState(_staged.clear);
    widget.onSend(text, paths);
    if (text.isNotEmpty) _focus.requestFocus();
  }

  // ── Press-and-hold dictation ──

  Future<void> _onMicDown() async {
    if (_isPointerDown) return;
    _isPointerDown = true;
    _startFailures = 0;
    _baseText = _controller.text;
    setState(() => _isListening = true);

    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
      if (!mounted) return;
      if (!_speechAvailable) {
        setState(() {
          _isListening = false;
          _isPointerDown = false;
        });
        WizToast.show(context, widget.speechUnavailableText);
        return;
      }
      await _resolveLocale();
    }

    await _enqueue(_startListening);
  }

  /// Asks the recognizer what it speaks and keeps the best match for the
  /// device's language list. A failure here is not fatal: dictation still runs
  /// on whatever locale the platform defaults to — which is why the lookup is
  /// capped. The Android 13+ path answers through a callback that reports
  /// errors by never calling back at all, and the hold is waiting on us.
  Future<void> _resolveLocale() async {
    try {
      final supported = await _speech.locales().timeout(_localeLookupTimeout);
      if (!mounted) return;
      _localeId = resolveSpeechLocaleId(
        supported: supported.map((l) => l.localeId).toList(),
        preferred: WidgetsBinding.instance.platformDispatcher.locales,
      );
    } on Exception {
      _localeId = null;
    }
  }

  Future<void> _onMicUp() async {
    if (!_isPointerDown) return;
    _isPointerDown = false;
    if (mounted) setState(() => _isListening = false);
    await _enqueue(_speech.stop);
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    // The OS ended the session (pause / length limit): keep going while the button is held.
    if (status == 'done' || status == 'notListening') {
      if (_isPointerDown) {
        _queueRestart();
      } else if (_isListening) {
        setState(() => _isListening = false);
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    final message = error.errorMsg;
    if (message.contains('error_listen_failed')) {
      _startFailures++;
    } else {
      _startFailures = 0;
    }
    // Silence, timeout or a lost audio session while holding: quietly restart.
    final recoverable = !_fatalSpeechErrors.contains(message);
    if (recoverable && _isPointerDown && _startFailures < _maxStartFailures) {
      _queueRestart();
      return;
    }
    setState(() {
      _isListening = false;
      _isPointerDown = false;
    });
    if (!message.contains('error_no_match') && !message.contains('error_speech_timeout')) {
      WizToast.show(context, widget.speechUnavailableText);
    }
  }

  /// Queues at most one restart; later reports of the same pause are dropped.
  void _queueRestart() {
    if (_restartQueued) return;
    _restartQueued = true;
    unawaited(_enqueue(_restartListening));
  }

  Future<void> _restartListening() async {
    _restartQueued = false;
    if (!_isPointerDown || !mounted) return;
    if (_speech.isListening) await _speech.stop();
    // Let the OS audio unit release the mic before requesting it again.
    await Future<void>.delayed(_micReleaseDelay);
    if (!_isPointerDown || !mounted) return;
    _baseText = _controller.text;
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_isPointerDown || !mounted || _speech.isListening) return;
    await _speech.listen(
      localeId: _localeId,
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        final base = _baseText.trimRight();
        final text = base.isEmpty ? words : '$base $words';
        if (_controller.text != text) {
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(14, 14, 14, widget.bottomPadding),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00E7F6F8), Color(0xF5E7F6F8)],
            stops: [0, 0.35],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_staged.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StagedStrip(
                  paths: _staged,
                  removeLabel: widget.removeScreenshotLabel,
                  onRemove: (final index) => setState(() => _staged.removeAt(index)),
                ),
              ),
            _row(),
          ],
        ),
      );

  Widget _row() => Row(
        children: [
          WizRoundIconButton(
            icon: Icons.add_rounded,
            size: 46,
            iconSize: 26,
            onPressed: _staged.length < AttachmentLimits.maxImages ? () => unawaited(_attach()) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: WizTextField(
              controller: _controller,
              focusNode: _focus,
              hintText: widget.hintText,
              height: 46,
              radius: 23,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              style: WizType.fieldText.copyWith(fontWeight: FontWeight.w500),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.showMic) ...[
            _MicButton(
              recording: _isListening,
              onDown: _onMicDown,
              onUp: _onMicUp,
            ),
            const SizedBox(width: 8),
          ],
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (final context, _, final __) => WizRoundIconButton(
              icon: Icons.arrow_upward_rounded,
              size: 46,
              onPressed: _canSend ? _send : null,
            ),
          ),
        ],
      );
}

/// The screenshots staged for the next turn: 48×64 thumbnails in a row, each with a remove
/// badge. Scrolls sideways once they no longer fit.
class _StagedStrip extends StatelessWidget {
  const _StagedStrip({required this.paths, required this.removeLabel, required this.onRemove});

  static const double _width = 48;
  static const double _height = 64;
  /// Room for the badge that overhangs each thumbnail's top-right corner.
  static const double _badgeInset = 6;

  final List<String> paths;
  final String removeLabel;
  final ValueChanged<int> onRemove;

  @override
  Widget build(final BuildContext context) => SizedBox(
        height: _height + _badgeInset,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: paths.length,
          separatorBuilder: (_, final __) => const SizedBox(width: 4),
          itemBuilder: (final context, final index) => Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: _badgeInset, right: _badgeInset),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AttachmentImage(path: paths[index], width: _width, height: _height),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Semantics(
                  button: true,
                  label: removeLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onRemove(index),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: WizColors.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// 46 px ink circle; while held it turns [WizColors.error] and shows the equalizer.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.recording, required this.onDown, required this.onUp});

  final bool recording;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: recording ? WizColors.error : WizColors.ink,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: recording
              ? const RecordingEqualizer()
              : const Icon(Icons.mic_none_rounded, size: 20, color: Colors.white),
        ),
      );
}

/// Four white bars waving between [minHeight] and [maxHeight] every [WizMotion.eq].
class RecordingEqualizer extends StatefulWidget {
  const RecordingEqualizer({
    super.key,
    this.barCount = 4,
    this.barWidth = 3,
    this.gap = 2,
    this.minHeight = 6,
    this.maxHeight = 18,
    this.color = Colors.white,
  });

  final int barCount;
  final double barWidth;
  final double gap;
  final double minHeight;
  final double maxHeight;
  final Color color;

  @override
  State<RecordingEqualizer> createState() => _RecordingEqualizerState();
}

class _RecordingEqualizerState extends State<RecordingEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WizMotion.eq,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.maxHeight - widget.minHeight;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.barCount, (i) {
          final phase = _controller.value * 2 * math.pi + i * 0.8;
          final height = widget.minHeight + range * (0.5 + 0.5 * math.sin(phase));
          return Container(
            margin: EdgeInsets.symmetric(horizontal: widget.gap / 2),
            width: widget.barWidth,
            height: height.clamp(widget.minHeight, widget.maxHeight),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.barWidth / 2),
            ),
          );
        }),
      ),
    );
  }
}
