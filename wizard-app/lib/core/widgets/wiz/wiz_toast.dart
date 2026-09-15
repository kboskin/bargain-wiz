import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Ink pill toast anchored 120px above the bottom, 1.5s, replaces any visible toast.
class WizToast {
  WizToast._();

  static OverlayEntry? _entry;

  static void show(BuildContext context, String text, {Duration? duration}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
      return;
    }
    hide();
    final entry = OverlayEntry(
      builder: (_) => _WizToastView(text: text),
    );
    _entry = entry;
    overlay.insert(entry);
    Future<void>.delayed(duration ?? WizMotion.toast, () {
      if (_entry == entry) hide();
    });
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _WizToastView extends StatefulWidget {
  const _WizToastView({required this.text});

  final String text;

  @override
  State<_WizToastView> createState() => _WizToastViewState();
}

class _WizToastViewState extends State<_WizToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        bottom: 120,
        child: IgnorePointer(
          child: Center(
            child: FadeTransition(
              opacity: _c,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: WizColors.ink,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: WizShadows.pill,
                    ),
                    child: Text(widget.text, style: WizType.toast),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
