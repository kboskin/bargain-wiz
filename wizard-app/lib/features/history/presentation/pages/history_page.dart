import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/core/widgets/wiz/wiz_text_field.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_labels.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/express_dealmaker_page.dart';
import 'package:appwizard/features/history/presentation/cubit/history_cubit.dart';
import 'package:appwizard/features/history/presentation/cubit/history_state.dart';
import 'package:appwizard/features/history/presentation/history_copy.dart';
import 'package:appwizard/features/history/presentation/widgets/history_empty_state.dart';
import 'package:appwizard/features/history/presentation/widgets/history_row.dart';
import 'package:appwizard/features/history/presentation/widgets/history_status_sheet.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/pages/pro_deal_closer_page.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// Bargains History tab body (search, filters, rows). Rendered inside the main
/// tab shell: no Scaffold of its own; the list leaves
/// [WizSpacing.tabBarContentPadding] at the bottom for the tab bar.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<HistoryCubit>(
        create: (_) => di.sl<HistoryCubit>()..load(),
        child: const HistoryView(),
      );
}

/// Tab body; expects a [HistoryCubit] above it.
class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final TextEditingController _search = TextEditingController();

  /// Cap the stagger so long lists do not keep late rows invisible.
  static const int _maxStaggerIndex = 10;

  /// The meta line's label for one deal: the first conversation-scoped answer it carries,
  /// as its onboarding option names it. Null when nothing is scoped to a conversation, or
  /// the config no longer offers that option — the row then falls back to its own copy.
  String? _scopedLabel(BuildContext context, Conversation conversation) {
    final field = ProfileFields.conversationScoped(di.sl<UserProfileService>().fields).firstOrNull;
    if (field == null) return null;
    final option = field.optionFor(conversation.overrides?[field.key]);
    return option == null ? null : TemplateText.textOf(context, option.label);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Conversation conversation) async {
    final cubit = context.read<HistoryCubit>();
    switch (conversation.type) {
      case ConversationType.express:
        await context.push(
          AppRoutes.express,
          extra: ExpressDealmakerArgs(conversationId: conversation.id),
        );
      case ConversationType.proDealCloser:
        await context.push(
          AppRoutes.pro,
          extra: ProDealCloserArgs(conversationId: conversation.id),
        );
    }
    if (!cubit.isClosed) await cubit.load();
  }

  Future<void> _editStatus(Conversation conversation) async {
    final cubit = context.read<HistoryCubit>();
    unawaited(HapticFeedback.lightImpact());
    final result = await HistoryStatusSheet.show(context, conversation);
    if (result == null || cubit.isClosed) return;
    await cubit.updateStatus(conversation.id, result.status, priceAfter: result.priceAfter);
  }

  void _delete(Conversation conversation) {
    unawaited(context.read<HistoryCubit>().delete(conversation.id));
    WizToast.show(context, HistoryCopy.of(context, HistoryCopy.dealRemoved));
  }

  String _filterLabel(BuildContext context, HistoryFilter filter) {
    final status = filter.status;
    if (status == null) return HistoryCopy.of(context, HistoryCopy.filterAll);
    return ConversationLabels.statusLabel(context, status);
  }

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context)?.bargainsHistory ??
        HistoryCopy.of(context, HistoryCopy.title);
    return SafeArea(
      bottom: false,
      child: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
          final cubit = context.read<HistoryCubit>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(WizSpacing.gutter, 8, WizSpacing.gutter, 0),
                child: Text(title, style: WizType.title),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WizSpacing.gutter),
                child: WizTextField(
                  controller: _search,
                  height: 46,
                  hintText: HistoryCopy.of(context, HistoryCopy.searchHint),
                  textInputAction: TextInputAction.search,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  onChanged: cubit.search,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: WizSpacing.gutter),
                child: Row(
                  children: [
                    for (final f in HistoryFilter.values) ...[
                      WizChip(
                        label: _filterLabel(context, f),
                        compact: true,
                        selected: state.filter == f,
                        fill: Colors.white,
                        onTap: () => cubit.setFilter(f),
                      ),
                      if (f != HistoryFilter.values.last) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              Expanded(child: _buildList(state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(HistoryState state) {
    const padding = EdgeInsets.fromLTRB(
      WizSpacing.gutter,
      12,
      WizSpacing.gutter,
      WizSpacing.tabBarContentPadding,
    );
    if (state.isLoading && !state.hasAny) return const SizedBox.shrink();
    final rows = state.visible;
    if (rows.isEmpty) {
      return ListView(
        padding: padding,
        children: [HistoryEmptyState(filtered: state.hasAny && state.isFiltering)],
      );
    }
    return ListView.separated(
      padding: padding,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: WizSpacing.stack),
      itemBuilder: (context, index) {
        final c = rows[index];
        return KeyedSubtree(
          key: ValueKey('history-${c.id}'),
          child: FadeUp(
            delay: WizMotion.historyStagger * math.min(index, _maxStaggerIndex),
            child: HistoryRow(
              conversation: c,
              scopedLabel: _scopedLabel(context, c),
              onTap: () => _open(c),
              onLongPress: () => _editStatus(c),
              onDismissed: () => _delete(c),
            ),
          ),
        );
      },
    );
  }
}
