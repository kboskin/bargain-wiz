import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_sheet.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_bloc.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_event.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_state.dart';
import 'package:appwizard/features/lines_that_land/presentation/pages/lines_tab_page.dart';
import 'package:appwizard/features/lines_that_land/presentation/utils/copied_line_tracker.dart';
import 'package:appwizard/features/lines_that_land/presentation/widgets/line_row.dart';

/// Legacy "Lines that land" bottom sheet (README §4): frosted 86%, radius 32, max-height 78%,
/// one pill line per category with "↻ Shuffle" cycling and a "1 of 3" footer.
///
/// Open with [LinesThatLandSheet.show]; the widget itself expects a [LinesThatLandBloc] above it.
class LinesThatLandSheet extends StatefulWidget {
  const LinesThatLandSheet({
    super.key,
    this.onClose,
    this.showHeader = true,
  });

  final VoidCallback? onClose;
  final bool showHeader;

  /// Shows the sheet with the app-wide [LinesThatLandBloc] (lazy singleton, cached result).
  static Future<void> show(BuildContext context) {
    final bloc = di.sl<LinesThatLandBloc>();
    return WizSheet.show<void>(
      context,
      builder: (ctx) => BlocProvider<LinesThatLandBloc>.value(
        value: bloc,
        child: LinesThatLandSheet(onClose: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  @override
  State<LinesThatLandSheet> createState() => _LinesThatLandSheetState();
}

class _LinesThatLandSheetState extends State<LinesThatLandSheet> {
  final CopiedLineTracker _copied = CopiedLineTracker();
  final Map<String, int> _index = {};
  bool _loadRequested = false;

  @override
  void dispose() {
    _copied.dispose();
    super.dispose();
  }

  void _shuffle(LinesThatLandCategory c) {
    final n = c.allTips.length;
    if (n <= 1) return;
    setState(() => _index[c.id] = ((_index[c.id] ?? 0) + 1) % n);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = di.sl<RemoteConfigService>().getMainPageConfig();
    final title = TemplateText.textOf(context, cfg?.generationCtaButton, fallback: 'Lines that land');

    return BlocBuilder<LinesThatLandBloc, LinesThatLandState>(
      builder: (context, state) {
        if (state is LinesThatLandInitial && !_loadRequested) {
          _loadRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.read<LinesThatLandBloc>().add(const LoadLinesThatLandRequested());
          });
        }
        return WizSheet(
          title: widget.showHeader ? title : null,
          onClose: widget.showHeader ? widget.onClose : null,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showHeader)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(LinesTabPage.defaultSubtitle, style: WizType.caption),
                ),
              _content(state),
            ],
          ),
        );
      },
    );
  }

  Widget _content(LinesThatLandState state) {
    if (state is LinesThatLandError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(state.message, style: WizType.bodyMd.copyWith(color: WizColors.errorText)),
      );
    }
    if (state is LinesThatLandLoaded) {
      if (state.categories.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Lines that land are coming soon.', style: WizType.bodyMd),
        );
      }
      return AnimatedBuilder(
        animation: _copied,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < state.categories.length; i++) ...[
              FadeUp(
                delay: WizMotion.listStagger * i,
                child: _CategoryCard(
                  category: state.categories[i],
                  index: _index[state.categories[i].id] ?? 0,
                  copied: _copied,
                  onShuffle: () => _shuffle(state.categories[i]),
                ),
              ),
              if (i < state.categories.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 160,
          height: 160,
          child: Lottie.asset(
            LinesTabPage.loadingVisual,
            fit: BoxFit.contain,
            repeat: true,
            options: LottieOptions(enableMergePaths: true),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.copied,
    required this.onShuffle,
  });

  final LinesThatLandCategory category;
  final int index;
  final CopiedLineTracker copied;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final tips = category.allTips;
    final i = tips.isEmpty ? 0 : index % tips.length;
    // Multilocale → current locale (falls back to English).
    final line = TemplateText.textOf(context, tips.isEmpty ? category.dailyTip.text : tips[i].text);
    final key = CopiedLineTracker.keyFor('sheet:${category.id}', i);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(WizRadii.cardLg),
        boxShadow: const [
          BoxShadow(color: Color(0x12463270), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    TemplateText.textOf(context, category.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WizType.cardTitle,
                  ),
                ),
                if (tips.length > 1)
                  WizTextLink(
                    label: '↻ Shuffle',
                    style: WizType.chip,
                    onPressed: onShuffle,
                  ),
              ],
            ),
          ),
          LineRow(
            pill: true,
            text: line,
            copied: copied.isCopied(key),
            onTap: () => copyLineToClipboard(context, copied, text: line, key: key),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 14),
            child: Text(
              '${i + 1} of ${tips.length}',
              style: WizType.chipSm.copyWith(fontWeight: FontWeight.w400, color: WizColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
