import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Entrance animation from the handoff: opacity 0→1, translateY 14→0, scale .98→1.
/// Use [delay] for stagger (e.g. index * WizMotion.listStagger).
class FadeUp extends StatefulWidget {
  const FadeUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = WizMotion.fadeUp,
    this.offset = 14,
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;
  /// When false the child is shown immediately without animation.
  final bool enabled;

  @override
  State<FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<FadeUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: WizMotion.easeOut,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _c.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - _a.value)),
            child: Transform.scale(
              scale: 0.98 + 0.02 * _a.value,
              child: child,
            ),
          ),
        ),
        child: widget.child,
      );
}

/// Convenience: wraps each child in a staggered [FadeUp].
class StaggeredFadeUpColumn extends StatelessWidget {
  const StaggeredFadeUpColumn({
    super.key,
    required this.children,
    this.stagger = WizMotion.listStagger,
    this.duration = WizMotion.fadeUp,
    this.gap = WizSpacing.stack,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.min,
    this.enabled = true,
  });

  final List<Widget> children;
  final Duration stagger;
  final Duration duration;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            FadeUp(
              delay: stagger * i,
              duration: duration,
              enabled: enabled,
              child: children[i],
            ),
            if (i < children.length - 1) SizedBox(height: gap),
          ],
        ],
      );
}

/// Gentle vertical bob (±4px, 1.6s ease-in-out) for hints.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.amplitude = 4});

  final Widget child;
  final double amplitude;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: WizMotion.bob,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -widget.amplitude * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: widget.child,
      );
}

/// Three blinking dots (typing indicator), 1.2s cycle with 0.2s offset.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color = WizColors.purple, this.size = 7});

  final Color color;
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: WizMotion.typingBlink,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value - i * (0.2 / 1.2)) % 1.0);
            final alpha = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: alpha.clamp(0.0, 1.0)),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      );
}
