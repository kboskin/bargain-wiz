import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';

/// Vertical trial timeline: 12px dots (ink / purple / amber), 2px connector, staggered entrance.
class PaywallTimeline extends StatefulWidget {
  const PaywallTimeline({super.key, required this.rows, this.animate = true});

  final List<PaywallTimelineRow> rows;
  final bool animate;

  @override
  State<PaywallTimeline> createState() => _PaywallTimelineState();
}

class _PaywallTimelineState extends State<PaywallTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.forward();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _itemAnimation(int i) {
    final start = (i * 0.25).clamp(0.0, 1.0);
    final end = (start + 0.5).clamp(0.0, 1.0);
    return CurvedAnimation(parent: _c, curve: Interval(start, end, curve: Curves.easeOutCubic));
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          _AnimatedRow(
            animation: _itemAnimation(i),
            child: _TimelineRow(row: rows[i], isLast: i == rows.length - 1),
          ),
      ],
    );
  }
}

class _AnimatedRow extends StatelessWidget {
  const _AnimatedRow({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - animation.value)),
            child: child,
          ),
        ),
        child: child,
      );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.row, required this.isLast});

  final PaywallTimelineRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(color: row.dotColor, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: isLast ? Colors.transparent : WizColors.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title, style: WizType.bodySmBold),
                    if (row.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(row.subtitle, style: WizType.caption),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
