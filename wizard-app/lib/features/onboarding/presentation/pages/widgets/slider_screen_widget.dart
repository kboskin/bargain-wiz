import 'dart:math' as math;

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';

/// `slider` template ("What's a typical deal for you?"): discrete stops with a
/// scaled Lottie, big value, subtext, savings pill and a 3-knob track.
/// Answer: option value as int (50 / 550 / 5000). A continuous fallback is kept
/// for legacy configs without `metadata.options`.
class SliderScreenWidget extends StatefulWidget {
  const SliderScreenWidget({
    required this.model,
    required this.onValueChanged,
    super.key,
    this.selectedValue,
    this.textColor = WizColors.ink,
  });

  final SliderScreenModel model;
  final num? selectedValue;
  final Color textColor;
  final ValueChanged<num> onValueChanged;

  @override
  State<SliderScreenWidget> createState() => _SliderScreenWidgetState();
}

class _SliderScreenWidgetState extends State<SliderScreenWidget> {
  List<SliderOption> get _options => widget.model.sortedOptions;

  int get _index {
    final opts = _options;
    if (opts.isEmpty) return 0;
    final v = widget.selectedValue;
    if (v == null) return widget.model.defaultIndex;
    var best = 0;
    for (var i = 1; i < opts.length; i++) {
      if ((opts[i].value - v).abs() < (opts[best].value - v).abs()) best = i;
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedValue == null && _options.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onValueChanged(_options[widget.model.defaultIndex].intValue);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final opts = _options;
    if (opts.isEmpty) return _ContinuousSlider(widget: widget);
    final index = _index;
    final current = opts[index];
    final pillTemplate = TemplateText.textOf(context, widget.model.savingsPill);
    final savings = current.savingsRange;
    final pill = savings == null || pillTemplate.isEmpty ? '' : TemplateText.fill(pillTemplate, {'savings': savings});

    return OnboardingScrollFill(
      children: [
        OnboardingScreenHeader(model: widget.model, textColor: widget.textColor, bottomGap: 0),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // No LayoutBuilder here: this column lives inside an IntrinsicHeight
              // (OnboardingScrollFill) and LayoutBuilder cannot report intrinsic sizes.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240, minHeight: 120),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedScale(
                      scale: current.scale ?? 1,
                      duration: WizMotion.fill,
                      curve: WizMotion.spring,
                      child: AnimatedSwitcher(
                        duration: WizMotion.fill,
                        child: current.animation == null
                            ? const SizedBox.shrink()
                            : VisualAssetWidget(
                                key: ValueKey(current.animation),
                                visualPath: current.animation!,
                                width: 240,
                                height: 240,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                TemplateText.textOf(context, current.label),
                style: WizType.bigValue.copyWith(color: widget.textColor, letterSpacing: -0.88),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                TemplateText.textOf(context, current.subtext),
                style: WizType.bodySmStrong.copyWith(color: WizColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (pill.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: WizColors.tealSoft,
                    borderRadius: BorderRadius.circular(WizRadii.chip),
                  ),
                  child: Text(
                    pill,
                    textAlign: TextAlign.center,
                    style: WizType.captionStrong.copyWith(color: WizColors.tealInk),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 18),
          child: _StopTrack(
            labels: [for (final o in opts) TemplateText.textOf(context, o.label)],
            index: index,
            onChanged: (i) => widget.onValueChanged(opts[i].intValue),
          ),
        ),
      ],
    );
  }
}

/// 8px ink track with N knobs (28px, 3px white border; ink when ≤ current) and labels below.
class _StopTrack extends StatelessWidget {
  const _StopTrack({required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    final fraction = n > 1 ? index / (n - 1) : 0.0;
    return Builder(
      builder: (trackContext) {
        void pickFromDx(double dx) {
          if (n <= 1) return;
          final box = trackContext.findRenderObject() as RenderBox?;
          final width = box?.size.width ?? 0;
          if (width <= 0) return;
          final t = (dx / width).clamp(0.0, 1.0);
          final i = (t * (n - 1)).round().clamp(0, n - 1);
          if (i != index) onChanged(i);
        }

        return Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => pickFromDx(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => pickFromDx(d.localPosition.dx),
              child: SizedBox(
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: WizColors.inkTrack,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.centerLeft,
                      child: AnimatedFractionallySizedBox(
                        duration: WizMotion.progress,
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        heightFactor: 1,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: WizColors.ink,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < n; i++)
                          GestureDetector(
                            onTap: () => onChanged(i),
                            child: AnimatedContainer(
                              duration: WizMotion.progress,
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: i <= index ? WizColors.ink : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x2E463270), blurRadius: 8, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: i == 0
                          ? TextAlign.left
                          : (i == n - 1 ? TextAlign.right : TextAlign.center),
                      style: WizType.footnote.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Legacy continuous mode (no `metadata.options`): min / max / step from metadata.
class _ContinuousSlider extends StatelessWidget {
  const _ContinuousSlider({required this.widget});

  final SliderScreenWidget widget;

  @override
  Widget build(BuildContext context) {
    final meta = widget.model.metadata;
    final min = meta?.rawDouble('min') ?? 0;
    final max = math.max(min + 1, meta?.rawDouble('max') ?? 100);
    final step = meta?.rawDouble('step');
    final value = (widget.selectedValue ?? meta?.rawDouble('default') ?? min).toDouble().clamp(min, max);
    final divisions = step != null && step > 0 ? ((max - min) / step).round() : null;
    final suffix = meta?.raw?['suffix']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingScreenHeader(model: widget.model, textColor: widget.textColor),
        Expanded(
          child: Center(
            child: Text(
              '${value.round()}$suffix',
              style: WizType.bigValue.copyWith(color: widget.textColor),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: WizColors.ink,
            inactiveTrackColor: WizColors.inkTrack,
            thumbColor: WizColors.ink,
            trackHeight: 8,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => widget.onValueChanged(step != null ? v.roundToDouble() : v),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
