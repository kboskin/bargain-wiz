import 'dart:async';
import 'dart:math' as math;

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_text_field.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Pro Deal Closer composer: "+" (attach) · text field · press-and-hold mic · send (↑).
/// Sits at the bottom of the screen over a fade from transparent to the app teal tint.
class ProComposer extends StatefulWidget {
  const ProComposer({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.showMic = true,
    this.hintText = 'Type a line...',
    this.speechUnavailableText = 'Speech recognition is not available on this device',
    this.bottomPadding = WizSpacing.homeIndicator,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  final bool showMic;
  final String hintText;
  final String speechUnavailableText;
  /// Bottom inset below the row (34 + safe area, or less when the keyboard is up).
  final double bottomPadding;

  @override
  State<ProComposer> createState() => _ProComposerState();
}

class _ProComposerState extends State<ProComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isPointerDown = false;

  /// Text already in the field when the mic was pressed; recognition appends after it.
  String _baseText = '';

  @override
  void dispose() {
    if (_speech.isListening) unawaited(_speech.cancel());
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _isPointerDown = false;
    if (_isListening) {
      _isListening = false;
      unawaited(_speech.stop());
    }
    _controller.clear();
    widget.onSend(text);
    _focus.requestFocus();
  }

  // ── Press-and-hold dictation ──

  Future<void> _onMicDown() async {
    if (_isListening) return;
    _isPointerDown = true;
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
    }

    if (!_isPointerDown) return;
    // Clear any stuck session before starting a new one.
    if (_speech.isListening) await _speech.cancel();
    await _startListening();
  }

  Future<void> _onMicUp() async {
    if (!_isPointerDown) return;
    _isPointerDown = false;
    if (mounted) setState(() => _isListening = false);
    await _speech.stop();
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    // The OS ended the session (pause / length limit): keep going while the button is held.
    if (status == 'done' || status == 'notListening') {
      if (_isPointerDown) {
        unawaited(_restartListening());
      } else if (_isListening) {
        setState(() => _isListening = false);
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    if (_isPointerDown) {
      // Silence / timeout while holding: quietly restart.
      unawaited(_restartListening());
      return;
    }
    setState(() {
      _isListening = false;
      _isPointerDown = false;
    });
    final message = error.errorMsg;
    if (!message.contains('error_no_match') && !message.contains('error_speech_timeout')) {
      WizToast.show(context, widget.speechUnavailableText);
    }
  }

  Future<void> _restartListening() async {
    if (!_isPointerDown || !mounted) return;
    if (_speech.isListening) {
      await _speech.stop();
      // Let the OS audio thread release the mic before requesting it again.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!_isPointerDown || !mounted) return;
    _baseText = _controller.text;
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_isPointerDown || !mounted) return;
    await _speech.listen(
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
        child: Row(
          children: [
            WizRoundIconButton(
              icon: Icons.add_rounded,
              size: 46,
              iconSize: 26,
              onPressed: widget.onAttach,
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
              builder: (context, value, _) => WizRoundIconButton(
                icon: Icons.arrow_upward_rounded,
                size: 46,
                onPressed: value.text.trim().isEmpty ? null : _send,
              ),
            ),
          ],
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
