import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_bloc.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_event.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_state.dart';
import 'package:appwizard/features/lines_that_land/presentation/utils/copied_line_tracker.dart';
import 'package:appwizard/features/lines_that_land/presentation/utils/lines_freshness.dart';
import 'package:appwizard/features/lines_that_land/presentation/widgets/line_row.dart';
import 'package:appwizard/features/main_shell/domain/main_tab.dart';
import 'package:appwizard/features/main_shell/presentation/main_shell_controller.dart';
import 'package:appwizard/features/main_shell/presentation/widgets/wiz_tab_bar.dart';

/// Lines that land tab body (README §4): every line of every category as a copyable row.
/// Rendered inside [MainShellPage]; leaves bottom padding for the tab bar.
///
/// Nothing is fetched at app start: the tab shows the on-device copy right away and asks the
/// bloc to refresh in the background the first time it becomes visible (or whenever the copy
/// is stale). Pull down to refresh by hand.
class LinesTabPage extends StatefulWidget {
  const LinesTabPage({super.key});

  static const String loadingVisual = 'assets/lottie/wizard_hello.json';
  static const String defaultSubtitle = 'Tap a line to copy and use in your chat';

  @override
  State<LinesTabPage> createState() => _LinesTabPageState();
}

class _LinesTabPageState extends State<LinesTabPage> {
  late final LinesThatLandBloc _bloc = di.sl<LinesThatLandBloc>();
  final CopiedLineTracker _copied = CopiedLineTracker();
  MainShellController? _shell;

  @override
  void initState() {
    super.initState();
    _bloc.add(const LinesThatLandPrimed());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = MainShellScope.maybeOf(context, listen: false);
    if (shell != _shell) {
      _shell?.removeListener(_onShellChanged);
      _shell = shell;
      _shell?.addListener(_onShellChanged);
      _onShellChanged();
    }
  }

  @override
  void dispose() {
    _shell?.removeListener(_onShellChanged);
    _copied.dispose();
    super.dispose();
  }

  /// Refresh only when this tab is the one on screen (no shell → shown standalone).
  void _onShellChanged() {
    final shell = _shell;
    if (shell == null || shell.tab == MainTab.lines) _bloc.add(const LinesThatLandOpened());
  }

  /// Pull-to-refresh: resolves when the refresh lands (success or failure).
  Future<void> _refresh() {
    _bloc.add(const LinesThatLandRefreshRequested());
    return _bloc.stream
        .firstWhere((s) => s is LinesThatLandError || (s is LinesThatLandLoaded && !s.isRefreshing))
        .then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final cfg = di.sl<RemoteConfigService>().getMainPageConfig();
    final title = TemplateText.textOf(context, cfg?.generationCtaButton, fallback: 'Lines that land');
    final bottomPad = WizTabBar.contentPaddingFor(context);

    return BlocProvider<LinesThatLandBloc>.value(
      value: _bloc,
      child: SafeArea(
        bottom: false,
        child: BlocConsumer<LinesThatLandBloc, LinesThatLandState>(
          listenWhen: (prev, curr) =>
              curr is LinesThatLandLoaded &&
              curr.refreshError != null &&
              (prev is! LinesThatLandLoaded || prev.refreshError == null),
          listener: (context, state) => WizToast.show(context, (state as LinesThatLandLoaded).refreshError!),
          builder: (context, state) {
            final header = <Widget>[
              const SizedBox(height: 18),
              Text(title, style: WizType.title),
              const SizedBox(height: 4),
              const Text(LinesTabPage.defaultSubtitle, style: WizType.bodyMd),
              if (state is LinesThatLandLoaded) ...[
                const SizedBox(height: 6),
                Text(
                  LinesFreshness.describe(
                        updatedAt: state.updatedAt,
                        refreshInterval: state.refreshInterval,
                        now: DateTime.now(),
                      ) +
                      (state.isRefreshing ? ' · Refreshing…' : ''),
                  style: WizType.caption.copyWith(color: WizColors.textTertiary),
                ),
              ],
              const SizedBox(height: 16),
            ];

            if (state is LinesThatLandLoaded && state.categories.isNotEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                color: WizColors.ink,
                child: AnimatedBuilder(
                  animation: _copied,
                  builder: (context, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(WizSpacing.gutter, 0, WizSpacing.gutter, bottomPad),
                    children: [
                      ...header,
                      for (var i = 0; i < state.categories.length; i++)
                        FadeUp(
                          delay: WizMotion.listStagger * i,
                          child: _CategorySection(category: state.categories[i], copied: _copied),
                        ),
                    ],
                  ),
                ),
              );
            }

            Widget body;
            if (state is LinesThatLandError) {
              body = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(state.message, style: WizType.bodyMd.copyWith(color: WizColors.errorText)),
                  const SizedBox(height: 16),
                  WizSecondaryButton(
                    label: 'Try again',
                    onPressed: () => _bloc.add(const LinesThatLandRefreshRequested()),
                  ),
                ],
              );
            } else if (state is LinesThatLandLoaded) {
              body = const Text('Lines that land are coming soon.', style: WizType.bodyMd);
            } else {
              body = Center(
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
              );
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(WizSpacing.gutter, 0, WizSpacing.gutter, bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...header, const SizedBox(height: 24), body],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.copied});

  final LinesThatLandCategory category;
  final CopiedLineTracker copied;

  @override
  Widget build(BuildContext context) {
    final tips = category.allTips;
    // Multilocale → current locale (falls back to English).
    final lines = [for (final t in tips) TemplateText.textOf(context, t.text)];
    return Padding(
      padding: const EdgeInsets.only(bottom: WizSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(TemplateText.textOf(context, category.name), style: WizType.cardTitle),
          ),
          for (var i = 0; i < tips.length; i++) ...[
            LineRow(
              text: lines[i],
              copied: copied.isCopied(CopiedLineTracker.keyFor(category.id, i)),
              onTap: () => copyLineToClipboard(
                context,
                copied,
                text: lines[i],
                key: CopiedLineTracker.keyFor(category.id, i),
              ),
            ),
            if (i < tips.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
