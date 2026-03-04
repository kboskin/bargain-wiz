import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/core/widgets/pastel_gradient_background.dart';
import 'package:appwizard/domain/entities/feedback_form_config.dart';
import 'package:appwizard/domain/entities/feedback_form_field.dart';
import 'package:appwizard/presentation/bloc/feedback/feedback_bloc.dart';
import 'package:appwizard/presentation/bloc/feedback/feedback_event.dart';
import 'package:appwizard/presentation/bloc/feedback/feedback_state.dart';

class FeedbackFormPage extends StatefulWidget {
  const FeedbackFormPage({super.key});

  @override
  State<FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _values = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(List<FeedbackFormField> fields) {
    for (final f in fields) {
      if (!_controllers.containsKey(f.id)) {
        _controllers[f.id] = TextEditingController(text: _values[f.id] ?? '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FeedbackBloc>(
      create: (_) => di.sl<FeedbackBloc>()..add(const LoadFeedbackFormRequested()),
      child: BlocConsumer<FeedbackBloc, FeedbackState>(
        listener: (context, state) {
          if (state is FeedbackSubmitSuccess) {
            context.pop();
          }
        },
        builder: (context, state) {
          return PastelGradientBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: state is FeedbackLoaded
                    ? StyledTitleWidget(
                        title: state.config.title,
                        baseColor: AppColors.textPrimary,
                        highlightWordsData: state.config.titleHighlightWords,
                        highlightColor: state.config.titleHighlightColor,
                        fontSize: 20.0,
                        fontSizeHighlight: 24.0,
                        fontWeight: FontWeight.w600,
                      )
                    : Text(
                        'Feedback',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textPrimary),
                  onPressed: () => context.pop(),
                ),
              ),
              body: _buildBody(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedbackState state) {
    if (state is FeedbackInitial || state is FeedbackLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is FeedbackError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassContainer(
            blurSigma: 16,
            color: Colors.white,
            opacity: 0.25,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      context.read<FeedbackBloc>().add(const LoadFeedbackFormRequested()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (state is FeedbackSubmitting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is FeedbackLoaded) {
      _initControllers(state.config.fields);
      return _buildForm(context, state.config);
    }
    return const SizedBox.shrink();
  }

  Widget _buildForm(BuildContext context, FeedbackFormConfig config) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: GlassContainer(
        blurSigma: 20,
        color: Colors.white,
        opacity: 0.25,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (config.description.isNotEmpty) ...[
              Text(
                config.description,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
            ],
            ...config.fields.map((field) => _buildField(context, field)),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => _submit(context, config),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                config.submitButtonText,
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, FeedbackFormField field) {
    final controller = _controllers[field.id];
    if (controller == null) return const SizedBox.shrink();

    final isMultiline = field.type == FeedbackFormFieldType.textarea;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          hintText: field.placeholder,
          labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.2),
        ),
        maxLines: isMultiline ? 4 : 1,
        onChanged: (value) => _values[field.id] = value,
      ),
    );
  }

  void _submit(BuildContext context, FeedbackFormConfig config) {
    final values = <String, String>{};
    for (final field in config.fields) {
      final controller = _controllers[field.id];
      final value = (controller?.text ?? _values[field.id] ?? '').trim();
      if (field.required && value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${field.label} is required')),
        );
        return;
      }
      if (value.isNotEmpty) {
        values[field.id] = value;
      }
    }
    context.read<FeedbackBloc>().add(FeedbackSubmitted(values));
  }
}
