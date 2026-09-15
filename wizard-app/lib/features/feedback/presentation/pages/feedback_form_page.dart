import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/pastel_gradient_background.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_header.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/core/widgets/wiz/wiz_text_field.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_config.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_field.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_state.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// Feedback form (`/feedback`): back chevron, remote-configured title / fields,
/// primary "Send" CTA, then a mascot success state with "Back to deals".
class FeedbackFormPage extends StatefulWidget {
  const FeedbackFormPage({super.key});

  @override
  State<FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {
  final Map<String, TextEditingController> _controllers = {};
  bool _showValidation = false;

  static const EdgeInsets _ctaPadding = EdgeInsets.fromLTRB(
    WizSpacing.gutter,
    8,
    WizSpacing.gutter,
    12,
  );

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(FeedbackFormField field) =>
      _controllers.putIfAbsent(field.id, TextEditingController.new);

  String _valueOf(FeedbackFormField field) => _controllers[field.id]?.text.trim() ?? '';

  bool _isInvalid(FeedbackFormField field) => field.required && _valueOf(field).isEmpty;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.main);
    }
  }

  void _submit(BuildContext context, FeedbackFormConfig config) {
    FocusScope.of(context).unfocus();
    if (config.fields.any(_isInvalid)) {
      setState(() => _showValidation = true);
      return;
    }
    final values = <String, String>{
      for (final field in config.fields)
        if (_valueOf(field).isNotEmpty) field.id: _valueOf(field),
    };
    context.read<FeedbackBloc>().add(FeedbackSubmitted(values));
  }

  @override
  Widget build(BuildContext context) => BlocProvider<FeedbackBloc>(
        create: (_) => di.sl<FeedbackBloc>()..add(const LoadFeedbackFormRequested()),
        child: BlocConsumer<FeedbackBloc, FeedbackState>(
          listener: (context, state) {
            if (state is FeedbackSubmitFailure) {
              final l10n = AppLocalizations.of(context);
              final message = state.message.trim();
              WizToast.show(context, message.isEmpty ? (l10n?.error ?? 'Error') : message);
            }
          },
          builder: (context, state) => PastelGradientBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    WizHeader(
                      title: '',
                      horizontalPadding: 16,
                      onBack: () => _back(context),
                    ),
                    Expanded(child: _buildBody(context, state)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildBody(BuildContext context, FeedbackState state) {
    if (state is FeedbackError) return _LoadError(message: state.message);
    if (state is FeedbackSubmitSuccess) {
      return _SuccessView(
        config: state.config,
        onDone: () => context.go(AppRoutes.main),
      );
    }
    if (state is FeedbackFormReady) {
      return _buildForm(context, state.config, submitting: state is FeedbackSubmitting);
    }
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: WizColors.ink),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    FeedbackFormConfig config, {
    required bool submitting,
  }) {
    final description = config.descriptionOf(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(WizSpacing.gutter, 8, WizSpacing.gutter, 12),
            child: FadeUp(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(config.titleOf(context), style: WizType.title),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description, style: WizType.bodyMd),
                  ],
                  const SizedBox(height: 20),
                  for (final field in config.fields) ...[
                    _buildField(context, config, field, enabled: !submitting),
                    const SizedBox(height: WizSpacing.stackLg),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: _ctaPadding,
          child: WizPrimaryButton(
            label: config.submitButtonTextOf(context),
            loading: submitting,
            onPressed: submitting ? null : () => _submit(context, config),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    BuildContext context,
    FeedbackFormConfig config,
    FeedbackFormField field, {
    required bool enabled,
  }) {
    final controller = _controllerFor(field);
    final isTextarea = field.type == FeedbackFormFieldType.textarea;
    final invalid = _showValidation && _isInvalid(field);
    final label = field.labelOf(context);
    final isEmail = field.id.toLowerCase().contains('email');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: WizType.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
        ],
        IgnorePointer(
          ignoring: !enabled,
          child: WizTextField(
            controller: controller,
            hintText: field.placeholderOf(context),
            height: isTextarea ? null : 52,
            minLines: isTextarea ? 5 : null,
            maxLines: isTextarea ? 8 : 1,
            error: invalid,
            keyboardType: isTextarea
                ? TextInputType.multiline
                : (isEmail ? TextInputType.emailAddress : TextInputType.text),
            textInputAction: isTextarea ? TextInputAction.newline : TextInputAction.next,
            textCapitalization:
                isTextarea ? TextCapitalization.sentences : TextCapitalization.none,
            contentPadding: isTextarea
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                : null,
            onChanged: _showValidation ? (_) => setState(() {}) : null,
          ),
        ),
        if (invalid) ...[
          const SizedBox(height: 6),
          Text(
            config.validationMessageOf(context),
            style: WizType.caption.copyWith(
              color: WizColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.config, required this.onDone});

  final FeedbackFormConfig config;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: WizSpacing.gutter),
                child: FadeUp(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const WizMascot(width: 150),
                      const SizedBox(height: 8),
                      Text(
                        config.successTitleOf(context),
                        textAlign: TextAlign.center,
                        style: WizType.title,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.successBodyOf(context),
                        textAlign: TextAlign.center,
                        style: WizType.bodyMd,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: _FeedbackFormPageState._ctaPadding,
            child: WizPrimaryButton(label: config.successCtaOf(context), onPressed: onDone),
          ),
        ],
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(WizSpacing.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message.isEmpty ? (l10n?.error ?? 'Error') : message,
            textAlign: TextAlign.center,
            style: WizType.bodyMd,
          ),
          const SizedBox(height: 20),
          WizSecondaryButton(
            label: l10n?.retry ?? 'Retry',
            onPressed: () =>
                context.read<FeedbackBloc>().add(const LoadFeedbackFormRequested()),
          ),
        ],
      ),
    );
  }
}
