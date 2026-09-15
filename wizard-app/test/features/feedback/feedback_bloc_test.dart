import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_config.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_field.dart';
import 'package:appwizard/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_state.dart';

class _FakeFeedbackRepository implements FeedbackRepository {
  Either<Failure, FeedbackFormConfig> configResult = const Left(CacheFailure('unset'));
  Either<Failure, void> submitResult = const Right(null);
  Map<String, String>? lastValues;
  String? lastUrl;

  @override
  Future<Either<Failure, FeedbackFormConfig>> getFeedbackFormConfig() async => configResult;

  @override
  Future<Either<Failure, void>> submitFeedback(Map<String, String> values, String submitUrl) async {
    lastValues = values;
    lastUrl = submitUrl;
    return submitResult;
  }
}

void main() {
  const config = FeedbackFormConfig(
    title: {'en': 'Send feedback', 'es': 'Enviar comentarios'},
    description: 'Help us improve.',
    submitButtonText: 'Send',
    submitUrl: 'https://example.com/api/feedback',
    fields: [
      FeedbackFormField(id: 'email', label: 'Email (optional)', type: FeedbackFormFieldType.text),
      FeedbackFormField(
        id: 'message',
        label: {'en': 'Your feedback'},
        type: FeedbackFormFieldType.textarea,
        required: true,
      ),
    ],
  );

  late _FakeFeedbackRepository repo;
  late FeedbackBloc bloc;
  late List<FeedbackState> states;
  late StreamSubscription<FeedbackState> sub;

  setUp(() {
    repo = _FakeFeedbackRepository();
    bloc = FeedbackBloc(repo);
    states = [];
    sub = bloc.stream.listen(states.add);
  });

  tearDown(() async {
    await sub.cancel();
    await bloc.close();
  });

  test('load emits Loading then Loaded with the config', () async {
    repo.configResult = const Right(config);
    bloc.add(const LoadFeedbackFormRequested());
    await pumpEventQueue();
    expect(states, const [FeedbackLoading(), FeedbackLoaded(config)]);
  });

  test('load failure emits FeedbackError and can be retried', () async {
    bloc.add(const LoadFeedbackFormRequested());
    await pumpEventQueue();
    expect(states.last, const FeedbackError('unset'));

    repo.configResult = const Right(config);
    bloc.add(const LoadFeedbackFormRequested());
    await pumpEventQueue();
    expect(states.last, const FeedbackLoaded(config));
  });

  test('submit failure keeps the config so the form stays on screen', () async {
    repo
      ..configResult = const Right(config)
      ..submitResult = const Left(ServerFailure('offline'));
    bloc.add(const LoadFeedbackFormRequested());
    await pumpEventQueue();
    states.clear();

    bloc.add(const FeedbackSubmitted({'message': 'Love it'}));
    await pumpEventQueue();

    expect(states, const [
      FeedbackSubmitting(config),
      FeedbackSubmitFailure(config, 'offline'),
    ]);
    expect(repo.lastValues, {'message': 'Love it'});
    expect(repo.lastUrl, 'https://example.com/api/feedback');

    // A retry after failure is accepted.
    repo.submitResult = const Right(null);
    states.clear();
    bloc.add(const FeedbackSubmitted({'email': 'a@b.co', 'message': 'Love it'}));
    await pumpEventQueue();
    expect(states, const [FeedbackSubmitting(config), FeedbackSubmitSuccess(config)]);
    expect(repo.lastValues, {'email': 'a@b.co', 'message': 'Love it'});
  });

  test('submit is ignored before the config is loaded and after success', () async {
    bloc.add(const FeedbackSubmitted({'message': 'x'}));
    await pumpEventQueue();
    expect(states, isEmpty);
    expect(repo.lastValues, isNull);

    repo.configResult = const Right(config);
    bloc.add(const LoadFeedbackFormRequested());
    await pumpEventQueue();
    bloc.add(const FeedbackSubmitted({'message': 'x'}));
    await pumpEventQueue();
    expect(states.last, const FeedbackSubmitSuccess(config));

    states.clear();
    bloc.add(const FeedbackSubmitted({'message': 'again'}));
    await pumpEventQueue();
    expect(states, isEmpty);
  });
}
