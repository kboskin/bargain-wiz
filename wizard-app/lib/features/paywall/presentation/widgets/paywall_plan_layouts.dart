import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_layout.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

typedef PaywallPriceLookup = String? Function(PaywallOption option);
typedef PaywallOptionSelected = void Function(PaywallOption option);

const Duration _kSwitch = Duration(milliseconds: 200);

/// Plan picker for the plans step; dispatches on `metadata.layout` (cards / list / compact).
class PaywallPlanPicker extends StatelessWidget {
  const PaywallPlanPicker({
    super.key,
    required this.config,
    required this.selectedId,
    required this.priceFor,
    required this.onSelect,
  });

  final PaywallConfig config;
  final String? selectedId;
  final PaywallPriceLookup priceFor;
  final PaywallOptionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    switch (config.metadata.layout) {
      case PaywallLayout.cards:
        return PaywallCardsLayout(
          options: config.options,
          metadata: config.metadata,
          selectedId: selectedId,
          priceFor: priceFor,
          onSelect: onSelect,
        );
      case PaywallLayout.list:
        return PaywallListLayout(
          options: config.options,
          selectedId: selectedId,
          priceFor: priceFor,
          onSelect: onSelect,
        );
      case PaywallLayout.compact:
        return PaywallCompactLayout(
          options: config.options,
          metadata: config.metadata,
          selectedId: selectedId,
          priceFor: priceFor,
          onSelect: onSelect,
        );
    }
  }
}

bool _isTextPlan(PaywallOption o) =>
    o.id == 'text' || (o.id != 'vision' && o.tierEnum == SubscriptionTier.basic);

Color _artBackground(PaywallOption o) => _isTextPlan(o) ? WizColors.mintSoft : WizColors.amberSoft;

/// Mascot (greyscale .7 for the text plan) or the remote visual when it is not a PNG.
class _PlanArt extends StatelessWidget {
  const _PlanArt({required this.option, required this.metadata, required this.size});

  final PaywallOption option;
  final PaywallMetadata? metadata;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = metadata?.optionVisuals[option.id] ?? '';
    final lower = path.toLowerCase();
    if (path.isNotEmpty && !lower.endsWith('.png') && !lower.endsWith('.jpg')) {
      return VisualAssetWidget(
        visualPath: path,
        width: size,
        height: size,
        repeat: metadata?.isAnimationLooped ?? true,
      );
    }
    final text = _isTextPlan(option);
    return WizMascot(width: size, greyscale: text, opacity: text ? 0.7 : 1);
  }
}

// ── cards ──────────────────────────────────────────────────────────────────

/// 2-column grid, gap 12, top padding 12 for the floating "Recommended" badge.
class PaywallCardsLayout extends StatelessWidget {
  const PaywallCardsLayout({
    super.key,
    required this.options,
    required this.metadata,
    required this.selectedId,
    required this.priceFor,
    required this.onSelect,
  });

  final List<PaywallOption> options;
  final PaywallMetadata metadata;
  final String? selectedId;
  final PaywallPriceLookup priceFor;
  final PaywallOptionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      final pair = options.sublist(i, (i + 2).clamp(0, options.length));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < pair.length; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              Expanded(
                child: _PlanCard(
                  option: pair[j],
                  metadata: metadata,
                  selected: pair[j].id == selectedId,
                  price: priceFor(pair[j]),
                  onTap: () => onSelect(pair[j]),
                ),
              ),
            ],
            if (pair.length == 1) ...[
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        ),
      ));
      if (i + 2 < options.length) rows.add(const SizedBox(height: 22));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.option,
    required this.metadata,
    required this.selected,
    required this.price,
    required this.onTap,
  });

  final PaywallOption option;
  final PaywallMetadata metadata;
  final bool selected;
  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = TemplateText.textOf(context, option.title);
    final desc = TemplateText.textOf(context, option.description);
    final badge = TemplateText.textOf(context, option.badge);

    return WizPressable(
      onTap: onTap,
      scale: 0.985,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: _kSwitch,
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(WizRadii.cardXl),
              border: Border.all(
                color: selected ? WizColors.ink : WizColors.border,
                width: 2,
              ),
              boxShadow: selected ? WizShadows.selectedPlan : const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 110,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _artBackground(option),
                    borderRadius: BorderRadius.circular(WizRadii.thumbLg),
                  ),
                  alignment: Alignment.center,
                  child: _PlanArt(option: option, metadata: metadata, size: 88),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: WizType.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: WizColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 34),
                  child: Text(
                    desc,
                    style: const TextStyle(
                      fontFamily: WizType.bodyFont,
                      fontSize: 12.5,
                      height: 1.35,
                      color: WizColors.textSecondary,
                    ),
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    price!,
                    style: const TextStyle(
                      fontFamily: WizType.display,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: WizColors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badge.isNotEmpty)
            Positioned(
              top: -10,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: WizColors.ink,
                  borderRadius: BorderRadius.circular(WizRadii.chip),
                ),
                child: Text(
                  badge,
                  style: WizType.badge.copyWith(color: WizColors.yellow),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── list ───────────────────────────────────────────────────────────────────

/// Rows (radius 18, 22px radio, inline badge, price right) + feature summary block.
class PaywallListLayout extends StatelessWidget {
  const PaywallListLayout({
    super.key,
    required this.options,
    required this.selectedId,
    required this.priceFor,
    required this.onSelect,
  });

  final List<PaywallOption> options;
  final String? selectedId;
  final PaywallPriceLookup priceFor;
  final PaywallOptionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.id == selectedId).firstOrNull ??
        (options.isNotEmpty ? options.first : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _PlanRow(
            option: options[i],
            selected: options[i].id == selectedId,
            price: priceFor(options[i]),
            onTap: () => onSelect(options[i]),
          ),
        ],
        if (selected != null && selected.features.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: WizColors.surfaceMuted,
              borderRadius: BorderRadius.circular(WizRadii.thumbXl),
            ),
            child: Text(
              '${TemplateText.textOf(context, selected.title)} includes: '
              '${selected.features.map((f) => f.get(context)).where((s) => s.isNotEmpty).join(' · ')}',
              style: WizType.caption.copyWith(height: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.option,
    required this.selected,
    required this.price,
    required this.onTap,
  });

  final PaywallOption option;
  final bool selected;
  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = TemplateText.textOf(context, option.title);
    final desc = TemplateText.textOf(context, option.description);
    final badge = TemplateText.textOf(context, option.badge);
    return WizPressable(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: _kSwitch,
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(WizRadii.card),
          border: Border.all(color: selected ? WizColors.ink : WizColors.border, width: 2),
          boxShadow: selected ? WizShadows.selectedPlan : const [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: _kSwitch,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? WizColors.ink : WizColors.borderStrong,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: _kSwitch,
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? WizColors.ink : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: WizType.optionLabel.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (badge.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        WizTag(
                          label: badge,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          style: WizType.badge.copyWith(fontSize: 10, letterSpacing: 0),
                        ),
                      ],
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc, style: WizType.caption),
                  ],
                ],
              ),
            ),
            if (price != null) ...[
              const SizedBox(width: 12),
              Text(
                price!,
                style: const TextStyle(
                  fontFamily: WizType.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: WizColors.ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── compact ────────────────────────────────────────────────────────────────

/// Segmented control + summary card (mascot 64, "Title · price", desc) + ✓ feature list.
class PaywallCompactLayout extends StatelessWidget {
  const PaywallCompactLayout({
    super.key,
    required this.options,
    required this.metadata,
    required this.selectedId,
    required this.priceFor,
    required this.onSelect,
  });

  final List<PaywallOption> options;
  final PaywallMetadata metadata;
  final String? selectedId;
  final PaywallPriceLookup priceFor;
  final PaywallOptionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final selected = options.where((o) => o.id == selectedId).firstOrNull ?? options.first;
    final title = TemplateText.textOf(context, selected.title);
    final desc = TemplateText.textOf(context, selected.description);
    final price = priceFor(selected);
    final features = selected.features.map((f) => f.get(context)).where((s) => s.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: WizColors.segmentTrack,
            borderRadius: BorderRadius.circular(WizRadii.chip),
          ),
          child: Row(
            children: [
              for (final o in options)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(o),
                    child: AnimatedContainer(
                      duration: _kSwitch,
                      curve: Curves.easeOut,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: o.id == selected.id ? WizColors.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(WizRadii.chip),
                        boxShadow: o.id == selected.id
                            ? const [
                                BoxShadow(
                                  color: Color(0x2E14121B),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : const [],
                      ),
                      child: Text(
                        TemplateText.textOf(context, o.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WizType.bodySmBold.copyWith(
                          color: o.id == selected.id ? Colors.white : WizColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WizColors.surfaceMuted,
            borderRadius: BorderRadius.circular(WizRadii.cardLg),
          ),
          child: Row(
            children: [
              _PlanArt(option: selected, metadata: metadata, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price == null ? title : '$title · $price',
                      style: const TextStyle(
                        fontFamily: WizType.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: WizColors.ink,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(desc, style: WizType.caption),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (features.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < features.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✓',
                  style: WizType.bodySmBold.copyWith(
                    color: WizColors.tealText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(features[i], style: WizType.bodySmStrong)),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
