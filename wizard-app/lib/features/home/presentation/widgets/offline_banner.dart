import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/network/network_info.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Ink pill (radius 12, Figtree 13/500 white, amber 8px dot) shown while the device is offline.
/// Initial value from [NetworkInfo], then follows the connectivity stream.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.text});

  final String text;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _check();
    try {
      _sub = Connectivity().onConnectivityChanged.listen(_onChanged, onError: (_) {});
    } catch (_) {
      // Plugin unavailable (tests / unsupported platform): stay online.
    }
  }

  Future<void> _check() async {
    try {
      final connected = await di.sl<NetworkInfo>().isConnected;
      if (mounted) setState(() => _offline = !connected);
    } catch (_) {}
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _offline) setState(() => _offline = offline);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: WizMotion.scrim,
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: _offline
            ? Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: WizColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: WizColors.warning, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: WizType.captionMedium.copyWith(color: Colors.white, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      );
}
