import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/domain/entities/conversation.dart';
import 'package:appwizard/core/utils/gallery_picker_helper.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/widgets/scanning_overlay.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Chat-style "Start with text" screen: input at top, AI suggestion bubbles
/// that appear to stack from the bottom, with a persistent bottom action bar.
class StartWithTextPage extends StatelessWidget {
  const StartWithTextPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
          color: AppColors.textPrimary,
        ),
        centerTitle: true,
        title: Text(
          'Deal lines',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const SafeArea(
        child: StartWithTextSection(),
      ),
    );
  }
}

/// Reusable chat UI: prompt bubble, focus input, hint, suggestion bubbles, bottom bar.
/// [embeddedInScrollView] true when used inside a scroll view (e.g. home); uses fixed height for the chat area.
/// [onScrollBackUp] when set (e.g. when embedded), show a control to scroll back to the main content.
class StartWithTextSection extends StatefulWidget {
  const StartWithTextSection({
    super.key,
    this.embeddedInScrollView = false,
    this.onScrollBackUp,
    this.initialMessages,
    this.onCloseConversation,
  });

  final bool embeddedInScrollView;
  final VoidCallback? onScrollBackUp;
  final List<ProDealCloserMessage>? initialMessages;
  final void Function(List<ProDealCloserMessage> messages)? onCloseConversation;

  @override
  State<StartWithTextSection> createState() => _StartWithTextSectionState();
}

class _StartWithTextSectionState extends State<StartWithTextSection> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  /// Sent messages (user bubbles). Text may be empty if only attachments were sent.
  final List<_ChatMessage> _messages = [];

  bool _hasMessageText = false;
  bool _isListening = false;
  bool _speechAvailable = false;

  /// While holding mic: text that was already in the field before press. New recognition appends after this.
  String _baseText = '';
  bool _isPointerDown = false;

  late final AppLogger _logger = di.sl<AppLogger>();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    final initial = widget.initialMessages;
    if (initial != null && initial.isNotEmpty) {
      for (final m in initial) {
        _messages.add(_ChatMessage(
          text: m.text,
          attachmentPaths: List<String>.from(m.attachmentPaths),
          isUploading: false,
        ));
      }
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildChatArea() => Stack(
    children: [
      ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 100,
        ),
        itemCount: _messages.length + 2,
        itemBuilder: (context, index) {
          if (index == _messages.length + 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPromptBubble(context),
                  const SizedBox(height: 12),
                  _buildHint(context),
                ],
              ),
            );
          }
          if (index == _messages.length) {
            return const SizedBox(height: 120);
          }
          final message = _messages[_messages.length - 1 - index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SuggestionBubble(
              text: message.text,
              attachmentPaths: message.attachmentPaths,
              isUploading: message.isUploading,
            ),
          );
        },
      ),
      _buildBottomBar(context),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final chatColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: 12,
            ),
            itemCount: _messages.length + 2,
            itemBuilder: (context, index) {
              if (index == _messages.length + 1) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPromptBubble(context),
                      const SizedBox(height: 12),
                      _buildHint(context),
                    ],
                  ),
                );
              }
              if (index == _messages.length) {
                return const SizedBox(height: 24);
              }
              final message = _messages[_messages.length - 1 - index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SuggestionBubble(
                  text: message.text,
                  attachmentPaths: message.attachmentPaths,
                  isUploading: message.isUploading,
                ),
              );
            },
          ),
        ),
        _buildInputBar(context),
      ],
    );

    if (widget.onScrollBackUp != null && widget.embeddedInScrollView) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                chatColumn,
                Positioned(
                  left: 0,
                  top: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 20, 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (_messages.isNotEmpty) {
                              final list = _messages
                                  .map((m) => ProDealCloserMessage(
                                text: m.text,
                                attachmentPaths: List<String>.from(m.attachmentPaths),
                              ))
                                  .toList();
                              widget.onCloseConversation?.call(list);
                            }
                            widget.onScrollBackUp?.call();
                          },
                          icon: const Icon(Icons.chevron_left),
                          color: AppColors.textPrimary,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.all(8),
                          ),
                          tooltip: 'Back to main',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.embeddedInScrollView) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: chatColumn)],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: _buildChatArea())],
    );
  }

  Widget _buildPromptBubble(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        "What's the deal about?",
        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
      ),
    ),
  );

  Widget _buildHint(BuildContext context) => const SizedBox.shrink();

  Widget _buildBottomBar(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _buildInputBar(context),
    );
  }

  /// Input bar content (text field + attach + mic + send). Used in Stack overlay or at bottom of Column.
  Widget _buildInputBar(BuildContext context) {
    final showMic =
        di.sl<RemoteConfigService>().getMainPageConfig()?.showMic ?? true;
    return Container(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.85),
        ],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildActionButton(
              icon: Icons.add_photo_alternate_outlined,
              enabled: true,
              onTap: _onAttachPressed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 120, // roughly 4 lines
                ),
                child: Scrollbar(
                  thumbVisibility: false,
                  child: TextField(
                    controller: _messageController,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: null, // grow vertically as text wraps
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Listening...' : 'Type a line...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: _isListening ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    onSubmitted: (_) => _onSendPressed(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          if (showMic) ...[
            _buildMicButton(context),
            const SizedBox(width: 8),
          ],
            _buildActionButton(
              icon: Icons.send,
              enabled: _canSend,
              onTap: _onSendPressed,
            ),
          ],
        ),
        ],
      ),
    );
  }

  void _onMessageChanged() {
    final text = _messageController.text.trim();
    final hasText = text.isNotEmpty;

    if (hasText != _hasMessageText) {
      setState(() {
        _hasMessageText = hasText;
      });
    }
  }

  bool get _canSend => _hasMessageText;

  Future<void> _onAttachPressed() async {
    final picked = await GalleryPickerHelper.pickImages(context);
    if (!mounted || picked.isEmpty) return;
    final paths = picked.map((x) => x.path).toList();
    setState(() {
      _messages.add(_ChatMessage(
        text: '',
        attachmentPaths: paths,
        isUploading: true,
      ));
    });
    _scheduleUploadDone(_messages.length - 1);

    // Scroll so the new message is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onSendPressed() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, attachmentPaths: const []));
      _messageController.clear();
    });

    // Clean up states
    _isPointerDown = false;
    _isListening = false;
    _speech.stop();

    // Scroll to bottom so new message appears above input (Telegram-style)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Simulates upload completion after a delay; replace message at [index] with isUploading: false.
  void _scheduleUploadDone(int index) {
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted || index >= _messages.length) return;
      setState(() {
        final m = _messages[index];
        _messages[index] = _ChatMessage(
          text: m.text,
          attachmentPaths: m.attachmentPaths,
          isUploading: false,
        );
      });
    });
  }

  Widget _buildActionButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  // 1. Better gesture handling to prevent accidental cancellations
  Widget _buildMicButton(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onMicPointerDown(),
      onTapUp: (_) => _onMicPointerUp(),
      onTapCancel: () => _onMicPointerUp(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isListening)
              const _RecordingEqualizer(
                barCount: 4,
                barWidth: 3,
                minHeight: 4,
                maxHeight: 16,
                color: Colors.white,
              )
            else
              const Icon(
                Icons.mic,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // 2. Refactored Mic Lifecycle Methods
  void _onMicPointerDown() async {
    if (_isListening) return;
    _isPointerDown = true;
    _baseText = _messageController.text;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device')),
        );
        return;
      }
    }

    if (!_isPointerDown) return;

    // Clear any "ghost" stuck state before starting
    if (_speech.isListening) {
      await _speech.cancel();
    }

    _startListening();
  }

  void _onMicPointerUp() async {
    if (!_isPointerDown) return;
    _isPointerDown = false;
    setState(() => _isListening = false);
    await _speech.stop();
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    // The OS naturally timed out due to a pause or length limit
    if (status == 'done' || status == 'notListening') {
      if (_isPointerDown) {
        // User is still holding the button! Quietly reboot the microphone.
        _restartListening();
      } else {
        setState(() => _isListening = false);
      }
    }
  }

  void _onSpeechError(dynamic error) {
    if (!mounted) return;

    // If the OS throws an error because it heard silence (error_no_match)
    // or timed out, we just ignore it and restart if they are holding the button.
    if (_isPointerDown) {
      _restartListening();
      return;
    }

    setState(() {
      _isListening = false;
      _isPointerDown = false;
    });

    final errorString = error.toString();
    if (!errorString.contains('error_no_match') && !errorString.contains('error_speech_timeout')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech error: $errorString')),
      );
    }
  }

  Future<void> _restartListening() async {
    if (!_isPointerDown || !mounted) return;

    // Only attempt to stop if it thinks it's still running, avoiding state conflicts
    if (_speech.isListening) {
      await _speech.stop();
      // A tiny breather allows the OS audio thread to release the mic
      // before we immediately request it again.
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!_isPointerDown || !mounted) return;

    // Lock in the text we've recorded so far as the new baseline
    _baseText = _messageController.text;

    // Start listening again seamlessly
    _startListening();
  }

  Future<void> _startListening() async {
    if (!_isPointerDown || !mounted) return;

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;

        final currentBase = _baseText.trimRight();
        final newText = currentBase.isEmpty ? words : '$currentBase $words';

        if (_messageController.text != newText) {
          _messageController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
          setState(() {});
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false, // Don't let native errors kill the UI state
    );
  }
}

/// Waving equalizer bars shown while recording (Telegram-style).
class _RecordingEqualizer extends StatefulWidget {
  const _RecordingEqualizer({
    this.barCount = 5,
    this.barWidth = 3,
    this.minHeight = 4,
    this.maxHeight = 20,
    this.color,
  });

  final int barCount;
  final double barWidth;
  final double minHeight;
  final double maxHeight;
  final Color? color;

  @override
  State<_RecordingEqualizer> createState() => _RecordingEqualizerState();
}

class _RecordingEqualizerState extends State<_RecordingEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.barCount, (i) {
          final phase = (_controller.value * 2 * math.pi) + (i * 0.8);
          final height = widget.minHeight + range * (0.5 + 0.5 * math.sin(phase));
          return Container(
            margin: EdgeInsets.symmetric(horizontal: widget.barWidth * 0.5),
            width: widget.barWidth,
            height: height.clamp(widget.minHeight, widget.maxHeight),
            decoration: BoxDecoration(
              color: widget.color ?? Colors.white,
              borderRadius: BorderRadius.circular(widget.barWidth / 2),
            ),
          );
        }),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    this.attachmentPaths = const [],
    this.isUploading = false,
  });

  final String text;
  final List<String> attachmentPaths;
  final bool isUploading;
}

class _SuggestionBubble extends StatelessWidget {
  const _SuggestionBubble({
    required this.text,
    this.attachmentPaths = const [],
    this.isUploading = false,
  });

  final String text;
  final List<String> attachmentPaths;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    const imageWidth = 165.0;
    const imageHeight = 280.0;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: attachmentPaths.isNotEmpty
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        decoration: attachmentPaths.isNotEmpty
            ? null
            : BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachmentPaths.isNotEmpty) ...[
              SizedBox(
                height: imageHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: attachmentPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ImageWithScanningOverlay(
                        width: imageWidth,
                        height: imageHeight,
                        borderRadius: 8,
                        isUploading: isUploading,
                        child: Image.file(
                          File(attachmentPaths[index]),
                          width: imageWidth,
                          height: imageHeight,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (text.isNotEmpty)
              Text(
                text,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              ),
          ],
        ),
      ),
    );
  }
}