import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/welcome_screen_config.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Autoplaying marketing video for the welcome hero (README §1 container).
///
/// Fills the hero (cover), loops and starts muted per [WelcomeVideoConfig]; a tap toggles
/// sound. [poster] is shown until the first frame is ready and whenever playback cannot
/// start (bad URL, unsupported codec, plugin unavailable), so the screen never goes blank.
/// Pauses while the app is in the background.
class WelcomeHeroVideo extends StatefulWidget {
  const WelcomeHeroVideo({required this.config, required this.poster, super.key});

  final WelcomeVideoConfig config;
  final Widget poster;

  @override
  State<WelcomeHeroVideo> createState() => _WelcomeHeroVideoState();
}

class _WelcomeHeroVideoState extends State<WelcomeHeroVideo> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  late bool _muted = widget.config.muted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    try {
      final url = widget.config.url.trim();
      final controller = widget.config.isNetwork
          ? VideoPlayerController.networkUrl(Uri.parse(url))
          : VideoPlayerController.asset(url);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(widget.config.loop);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } on Object catch (_) {
      // Keep the poster; the video is decorative and must never block the CTA.
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggleSound() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    setState(() => _muted = !_muted);
    await controller.setVolume(_muted ? 0 : 1);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (state == AppLifecycleState.resumed) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // A controller whose initialize() failed has nothing to release; disposing it would
    // await a completer that never completes.
    if (_ready) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || !_ready || controller == null) return widget.poster;
    final size = controller.value.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleSound,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width == 0 ? 16 : size.width,
              height: size.height == 0 ? 9 : size.height,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _SoundBadge(muted: _muted),
          ),
        ],
      ),
    );
  }
}

class _SoundBadge extends StatelessWidget {
  const _SoundBadge({required this.muted});

  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(color: Color(0xCCFFFFFF), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(
          muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          size: 18,
          color: WizColors.ink,
        ),
      );
}
