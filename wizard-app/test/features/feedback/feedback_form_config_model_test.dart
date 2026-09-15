import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/feedback/data/mappers/feedback_form_mapper.dart';
import 'package:appwizard/features/feedback/data/models/feedback_form_config_model.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_config.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_field.dart';

/// `feedback_form_config` from the bundled remote-config defaults (stored as a JSON string).
Map<String, dynamic> loadDefaultFeedbackConfig() {
  final raw = File('assets/config/remote_config_defaults.json').readAsStringSync();
  final all = jsonDecode(raw) as Map<String, dynamic>;
  final value = all['feedback_form_config'];
  final decoded = value is String ? jsonDecode(value) : value;
  return Map<String, dynamic>.from(decoded as Map);
}

Widget host(Locale locale, WidgetBuilder builder) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      home: Builder(builder: builder),
    );

void main() {
  final mapper = FeedbackFormMapper();

  group('FeedbackFormConfigModel.fromJson (multilocale defaults)', () {
    late FeedbackFormConfigModel model;

    setUp(() => model = FeedbackFormConfigModel.fromJson(loadDefaultFeedbackConfig()));

    test('keeps multilocale copy as maps and parses the new success / validation keys', () {
      expect(model.title, isA<Map>());
      expect((model.title as Map)['es'], 'Enviar comentarios');
      expect(model.description, isA<Map>());
      expect(model.submitButtonText, isA<Map>());
      expect(model.submitUrl, 'https://example.com/api/feedback');
      expect(model.successTitle, isA<Map>());
      expect(model.successBody, isA<Map>());
      expect(model.successCta, isA<Map>());
      expect(model.validationMessage, isA<Map>());
    });

    test('parses fields with mixed plain / multilocale labels and placeholders', () {
      expect(model.fields.length, 2);
      final email = model.fields.first;
      final message = model.fields.last;
      expect(email.id, 'email');
      expect(email.type, 'text');
      expect(email.required, isFalse);
      expect(email.label, isA<Map>());
      expect(email.placeholder, 'your@email.com');
      expect(message.id, 'message');
      expect(message.type, 'textarea');
      expect(message.required, isTrue);
      expect(message.placeholder, isA<Map>());
    });

    testWidgets('entity resolves copy for es and en', (tester) async {
      final config = mapper.toEntity(model);
      late String esTitle;
      late String esLabel;
      late String esValidation;
      late String esPlaceholder;
      await tester.pumpWidget(host(const Locale('es'), (context) {
        esTitle = config.titleOf(context);
        esLabel = config.fields.last.labelOf(context);
        esValidation = config.validationMessageOf(context);
        esPlaceholder = config.fields.first.placeholderOf(context);
        return const SizedBox();
      }));
      expect(esTitle, 'Enviar comentarios');
      expect(esLabel, 'Tus comentarios');
      expect(esValidation, 'Añade un mensaje antes de enviar.');
      expect(esPlaceholder, 'your@email.com');

      late String enTitle;
      late String enCta;
      late String enSuccessTitle;
      late String enSuccessBody;
      await tester.pumpWidget(host(const Locale('en'), (context) {
        enTitle = config.titleOf(context);
        enCta = config.successCtaOf(context);
        enSuccessTitle = config.successTitleOf(context);
        enSuccessBody = config.successBodyOf(context);
        return const SizedBox();
      }));
      expect(enTitle, 'Send feedback');
      expect(enCta, 'Back to deals');
      expect(enSuccessTitle, 'Thank you');
      expect(enSuccessBody, 'Your note is with the wizards.');
    });
  });

  group('FeedbackFormConfigModel.fromJson (legacy plain strings)', () {
    final legacy = <String, dynamic>{
      'title': 'Feedback',
      'description': 'Tell us more',
      'submit_button_text': 'Go',
      'submit_url': 'https://legacy.example.com',
      'fields': [
        {'id': 'message', 'label': 'Message', 'type': 'TEXTAREA', 'required': true, 'placeholder': 'Type here'},
        {'id': 'name', 'label': 'Name'},
      ],
    };

    test('plain strings pass through and missing keys become null', () {
      final model = FeedbackFormConfigModel.fromJson(legacy);
      expect(model.title, 'Feedback');
      expect(model.description, 'Tell us more');
      expect(model.submitButtonText, 'Go');
      expect(model.successTitle, isNull);
      expect(model.validationMessage, isNull);
      expect(model.fields.first.type, 'textarea');
      expect(model.fields.last.type, 'text');
      expect(model.fields.last.placeholder, isNull);
    });

    testWidgets('entity falls back to English defaults for missing copy', (tester) async {
      final config = mapper.toEntity(FeedbackFormConfigModel.fromJson(legacy));
      late String title;
      late String submit;
      late String successTitle;
      late String successCta;
      late String validation;
      late String namePlaceholder;
      await tester.pumpWidget(host(const Locale('es'), (context) {
        title = config.titleOf(context);
        submit = config.submitButtonTextOf(context);
        successTitle = config.successTitleOf(context);
        successCta = config.successCtaOf(context);
        validation = config.validationMessageOf(context);
        namePlaceholder = config.fields.last.placeholderOf(context);
        return const SizedBox();
      }));
      expect(title, 'Feedback');
      expect(submit, 'Go');
      expect(successTitle, FeedbackFormConfig.defaultSuccessTitle);
      expect(successCta, FeedbackFormConfig.defaultSuccessCta);
      expect(validation, FeedbackFormConfig.defaultValidationMessage);
      expect(namePlaceholder, '');
      expect(config.fields.first.type, FeedbackFormFieldType.textarea);
      expect(config.fields.first.required, isTrue);
    });

    test('empty json yields a usable config with defaults', () {
      final model = FeedbackFormConfigModel.fromJson(<String, dynamic>{});
      expect(model.fields, isEmpty);
      expect(model.title, isNull);
      expect(model.submitUrl, '');
      expect(FeedbackFormConfigModel.text(''), isNull);
      expect(FeedbackFormConfigModel.text(<String, dynamic>{}), isNull);
      expect(FeedbackFormConfigModel.text(42), isNull);
    });
  });
}
