import 'dart:math' as math;

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// `slider_lottie` template ("How hard do you push?"): a Lottie tube filled to
/// the chosen stop + a column of stop pills. Answer: stop value (20…100).
class SliderLottieScreenWidget extends StatefulWidget {
  const SliderLottieScreenWidget({
    required this.model,
    required this.onValueChanged,
    super.key,
    this.selectedValue,
    this.textColor = WizColors.ink,
  });

  final SliderLottieScreenModel model;
  final num? selectedValue;
  final Color textColor;
  final ValueChanged<int> onValueChanged;

  @override
  State<SliderLottieScreenWidget> createState() => _SliderLottieScreenWidgetState();
}

class _SliderLottieScreenWidgetState extends State<SliderLottieScreenWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottie = AnimationController(vsync: this, duration: WizMotion.fill);
  late final AssetPathHelper _paths = di.sl<AssetPathHelper>();

  List<PushStopOption> get _stops => widget.model.stops;

  int get _index => widget.model.stopIndexFor(widget.selectedValue);

  @override
  void initState() {
    super.initState();
    _lottie.value = _progressFor(_index);
    if (widget.selectedValue == null && _stops.isNotEmpty) {
      // Pre-fill the default so the CTA is enabled straight away.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onValueChanged(_stops[_index].value);
      });
    }
  }

  @override
  void didUpdateWidget(SliderLottieScreenWidget old) {
    super.didUpdateWidget(old);
    if (old.selectedValue != widget.selectedValue) {
      _lottie.animateTo(_progressFor(_index), duration: WizMotion.fill, curve: WizMotion.spring);
    }
  }

  double _progressFor(int index) {
    if (_stops.isEmpty) return 0;
    // Stops are percentages (20…100) → Lottie progress 0…1.
    return (_stops[index].value / 100).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _lottie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    if (stops.isEmpty) return OnboardingScreenHeader(model: widget.model, textColor: widget.textColor);
    final index = _index;
    final current = stops[index];
    final color = wizHexColor(current.colorHex) ?? WizColors.push[math.min(index, WizColors.push.length - 1)];
    final fill = (index + 1) / stops.length;
    final path = _paths.normalizeAssetPath(widget.model.visual ?? 'assets/lottie/lottie_tube.json');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingScreenHeader(model: widget.model, textColor: widget.textColor, bottomGap: 0),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tube = math.min(200.0, math.max(120.0, constraints.maxWidth - 26 - 150));
              return Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Tube(path: path, size: tube, controller: _lottie, color: color, fill: fill),
                    const SizedBox(width: 26),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < stops.length; i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            _StopPill(
                              stop: stops[i],
                              selected: i == index,
                              onTap: () => widget.onValueChanged(stops[i].value),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              AnimatedContainer(
                duration: WizMotion.fill,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(WizRadii.chip)),
                child: Text(
                  '${current.emoji} ${TemplateText.textOf(context, current.label)}'.trim(),
                  style: WizType.bodySmBold.copyWith(color: Colors.white, height: 1.2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                TemplateText.textOf(context, current.subtext),
                style: WizType.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tube extends StatelessWidget {
  const _Tube({
    required this.path,
    required this.size,
    required this.controller,
    required this.color,
    required this.fill,
  });

  final String path;
  final double size;
  final AnimationController controller;
  final Color color;
  final double fill;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Lottie.asset(
                path,
                controller: controller,
                fit: BoxFit.contain,
                repeat: false,
                frameRate: const FrameRate(60),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedFractionallySizedBox(
                  duration: WizMotion.fill,
                  curve: WizMotion.spring,
                  heightFactor: fill.clamp(0.0, 1.0),
                  widthFactor: 1,
                  child: AnimatedContainer(
                    duration: WizMotion.fill,
                    color: color.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StopPill extends StatelessWidget {
  const _StopPill({required this.stop, required this.selected, required this.onTap});

  final PushStopOption stop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = wizHexColor(stop.colorHex) ?? WizColors.ink;
    return WizPressable(
      onTap: onTap,
      scale: 0.97,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0x99FFFFFF),
            borderRadius: BorderRadius.circular(WizRadii.chip),
            border: Border.all(color: selected ? color : WizColors.frostedBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stop.emoji, style: const TextStyle(fontSize: 16, height: 1.2)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  TemplateText.textOf(context, stop.label),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: WizType.bodySmBold.copyWith(height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
