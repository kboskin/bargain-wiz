import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_layout.dart';
import 'package:appwizard/features/home/presentation/widgets/highlighted_text.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';

typedef PaywallPriceLookup = String? Function(PaywallOption option);

/// The trial length that applies to one option (its own, else the paywall default).
typedef PaywallTrialLookup = int Function(PaywallOption option);
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

  int _trialDaysOf(PaywallOption option) => option.trialDaysOr(config.trialDays);

  @override
  Widget build(BuildContext context) {
    switch (config.metadata.layout) {
      case PaywallLayout.cards:
        return PaywallCardsLayout(
          options: config.options,
          metadata: config.metadata,
          selectedId: selectedId,
          priceFor: priceFor,
          trialDaysOf: _trialDaysOf,
          onSelect: onSelect,
        );
      case PaywallLayout.list:
        return PaywallListLayout(
          options: config.options,
          selectedId: selectedId,
          priceFor: priceFor,
          trialDaysOf: _trialDaysOf,
          cardStyle: config.metadata.cardStyle,
          metadata: config.metadata,
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

/// `art_color` when the plan sets one, else the handoff's tints: amber for the plan the
/// config preselects, mint for the rest.
Color _artBackground(PaywallOption o, PaywallMetadata? metadata) =>
    PaywallBackgroundConfig.parseHex(o.artColor ?? '') ??
    (metadata == null || o.id == metadata.defaultSelectedOptionId
        ? WizColors.amberSoft
        : WizColors.mintSoft);

/// The emphasis a selected card carries, from `metadata.card_style`.
extension PaywallCardStyleShadow on PaywallCardStyle {
  List<BoxShadow> get selectedShadow {
    switch (this) {
      case PaywallCardStyle.glow:
        return WizShadows.selectedPlan;
      case PaywallCardStyle.shadow:
        return WizShadows.card;
      case PaywallCardStyle.flat:
        return const [];
    }
  }
}

/// How a price is drawn, wherever a layout draws one: light by default, and haloed only on
/// the card being bought. Shared so the three layouts cannot disagree about it.
TextStyle priceStyleOf(PaywallMetadata metadata, {required bool selected}) => TextStyle(
      fontFamily: metadata.priceFamily,
      fontSize: metadata.priceSize,
      fontWeight: metadata.priceWeight,
      color: WizColors.ink,
      shadows: selected && metadata.isPriceGlowing ? WizShadows.textGlow : null,
    );

/// The badges a plan card shows, in reading order.
///
/// The trial comes first and only while the period has one — its text is reachable only
/// through `trial_days`, so a card cannot go on promising a trial the offer has dropped.
/// Everything after it is whatever `badges` lists ("Save 34%"), unchanged by the app. A
/// config from before the row existed still works: its single `badge` is the whole row.
List<String> badgesFor(PaywallOption option, int trialDays, PaywallTextResolver resolve) {
  final out = <String>[];
  if (trialDays > 0 && option.trialBadge != null) {
    final trial = resolve(option.trialBadge!.sourceFor(trialDays)).trim();
    if (trial.isNotEmpty) out.add(TemplateText.fill(trial, {'n': '$trialDays'}));
  }
  final configured = option.badges.isNotEmpty
      ? option.badges.map(resolve)
      : [resolve(option.badge)];
  out.addAll(configured.map((b) => b.trim()).where((b) => b.isNotEmpty));
  return out;
}

/// One ink pill with yellow text, the badge shape from the handoff.
class PaywallBadgePill extends StatelessWidget {
  const PaywallBadgePill({super.key, required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 2 : 3),
        decoration: BoxDecoration(
          color: WizColors.ink,
          borderRadius: BorderRadius.circular(WizRadii.chip),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WizType.badge.copyWith(
            color: WizColors.yellow,
            fontSize: compact ? 10 : null,
            letterSpacing: compact ? 0 : null,
          ),
        ),
      );
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
    required this.trialDaysOf,
    required this.onSelect,
  });

  final List<PaywallOption> options;
  final PaywallMetadata metadata;
  final String? selectedId;
  final PaywallPriceLookup priceFor;
  final PaywallTrialLookup trialDaysOf;
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
                  trialDays: trialDaysOf(pair[j]),
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
    required this.trialDays,
    required this.onTap,
  });

  final PaywallOption option;
  final PaywallMetadata metadata;
  final bool selected;
  final String? price;

  /// This option's trial length; drives whether the trial pill is shown at all.
  final int trialDays;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = TemplateText.textOf(context, option.title);
    final desc = TemplateText.textOf(context, option.description);
    final badges = badgesFor(option, trialDays, (v) => TemplateText.textOf(context, v));
    final descriptionStyle = TextStyle(
      fontFamily: WizType.bodyFont,
      fontSize: metadata.descriptionSize,
      height: 1.35,
      color: WizColors.textSecondary,
    );

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
              boxShadow: selected ? metadata.cardStyle.selectedShadow : const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: metadata.artBlockHeight,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _artBackground(option, metadata),
                    borderRadius: BorderRadius.circular(WizRadii.thumbLg),
                  ),
                  alignment: Alignment.center,
                  child: VisualAssetWidget(
                    visualPath: metadata.artPathFor(option.id),
                    width: metadata.artWidth,
                    height: metadata.artHeight,
                    repeat: metadata.isAnimationLooped,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: WizType.display,
                    fontSize: metadata.titleSize,
                    fontWeight: FontWeight.w700,
                    color: WizColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 34),
                  child: Text.rich(
                    TextSpan(
                      children: HighlightedText.buildSpans(
                        desc,
                        descriptionStyle,
                        option.descriptionHighlightWords,
                      ),
                    ),
                    style: descriptionStyle,
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(height: 6),
                  Text(price!, style: priceStyleOf(metadata, selected: selected)),
                ],
              ],
            ),
          ),
          if (badges.isNotEmpty)
            Positioned(
              // Straddles the card's top edge as the handoff drew it. A row that outgrows the
              // card wraps downward over the art rather than clipping, so the number of
              // badges stays the template's business.
              top: -10,
              left: 14,
              right: 14,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [for (final b in badges) PaywallBadgePill(label: b)],
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
    required this.trialDaysOf,
    required this.onSelect,
    required this.metadata,
    this.cardStyle = PaywallCardStyle.glow,
  });

  final List<PaywallOption> options;
  final String? selectedId;
  final PaywallPriceLookup priceFor;
  final PaywallTrialLookup trialDaysOf;
  final PaywallOptionSelected onSelect;
  final PaywallCardStyle cardStyle;
  final PaywallMetadata metadata;

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
            trialDays: trialDaysOf(options[i]),
            cardStyle: cardStyle,
            metadata: metadata,
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
    required this.trialDays,
    required this.cardStyle,
    required this.metadata,
    required this.onTap,
  });

  final PaywallOption option;
  final bool selected;
  final String? price;
  final int trialDays;
  final PaywallCardStyle cardStyle;
  final PaywallMetadata metadata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = TemplateText.textOf(context, option.title);
    final desc = TemplateText.textOf(context, option.description);
    final badges = badgesFor(option, trialDays, (v) => TemplateText.textOf(context, v));
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
          boxShadow: selected ? cardStyle.selectedShadow : const [],
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
                      for (final b in badges) ...[
                        const SizedBox(width: 8),
                        PaywallBadgePill(label: b, compact: true),
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
              Text(price!, style: priceStyleOf(metadata, selected: selected)),
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
              VisualAssetWidget(
                visualPath: metadata.artPathFor(selected.id),
                width: 64,
                height: 64,
                repeat: metadata.isAnimationLooped,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: title),
                          if (price != null)
                            TextSpan(
                              text: '  $price',
                              style: priceStyleOf(metadata, selected: true),
                            ),
                        ],
                      ),
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
