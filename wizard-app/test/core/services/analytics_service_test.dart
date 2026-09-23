import 'package:appwizard/core/services/analytics_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAnalytics implements FirebaseAnalytics {
  final events = <({String name, Map<String, Object>? parameters})>[];
  final screens = <({String? name, String? screenClass, Map<String, Object>? parameters})>[];

  /// Everything, in the order it was sent.
  final calls = <String>[];
  final userIds = <String?>[];
  final properties = <String, String?>{};

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add('event:$name');
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add('screen:$screenName');
    screens.add((name: screenName, screenClass: screenClass, parameters: parameters));
  }

  @override
  Future<void> setUserId({String? id, AnalyticsCallOptions? callOptions}) async => userIds.add(id);

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async =>
      properties[name] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _FakeAnalytics analytics;
  late AnalyticsService service;

  setUp(() {
    analytics = _FakeAnalytics();
    service = AnalyticsService(logger: _SilentLogger(), analytics: analytics);
  });

  group('identity', () {
    test('the uid is the only thing reported about the person', () async {
      await service.setUserId('anon-1');

      expect(analytics.userIds, ['anon-1']);
      expect(analytics.properties, isEmpty, reason: 'no user properties, anywhere');
    });
  });

  group('screen views', () {
    test('a screen carrying parameters sends them on the screen view itself', () async {
      await service.logScreenView(
        screenName: 'onboarding/vibe',
        screenClass: 'OnboardingFlowPage',
        parameters: {'step_index': 2, 'step_count': 9},
      );

      expect(analytics.calls, ['screen:onboarding/vibe'], reason: 'no second event beside it');
      final screen = analytics.screens.single;
      expect(screen.screenClass, 'OnboardingFlowPage');
      expect(screen.parameters, {'step_index': 2, 'step_count': 9});
    });

    test('a screen view without parameters sends none', () async {
      await service.logScreenView(screenName: 'paywall');

      expect(analytics.screens.single.parameters, isNull);
    });

    test('parameters are converted for the SDK wherever they are sent', () async {
      await service.logScreenView(screenName: 'x', parameters: {'flag': true, 'n': 3});

      expect(analytics.screens.single.parameters, {'flag': 'true', 'n': 3});
    });
  });

  group('onboarding funnel', () {

    test('a step reports the answers it writes and what was picked, one parameter per key', () async {
      await service.logOnboardingStepAnswered(
        index: 4,
        stepId: 'marketplace',
        stepType: 'select_group',
        answerKeys: ['marketplace', 'deal_size'],
        answers: {'marketplace': 'ebay', 'deal_size': 550},
      );

      expect(analytics.events.single.parameters, {
        'marketplace': 'ebay',
        'deal_size': 550,
        'step_index': 4,
        'step_id': 'marketplace',
        'step_type': 'select_group',
        'answer_keys': 'marketplace,deal_size',
      });
    });

    test("a multi-select is comma-joined, and the step's own parameters win a name clash", () async {
      await service.logOnboardingStepAnswered(
        index: 0,
        stepId: 'hurdles',
        stepType: 'multiSelect',
        answerKeys: ['hurdles'],
        answers: {'hurdles': ['starting', 'fair_price'], 'step_index': 'x'},
      );

      final params = analytics.events.single.parameters!;
      expect(params['hurdles'], 'starting,fair_price');
      expect(params['step_index'], 0);
    });

    test('a screen that asks nothing leaves the parameter out entirely', () async {
      await service.logOnboardingStepAnswered(index: 0, stepId: 'warmup', stepType: 'warmup');

      expect(analytics.events.single.parameters?.containsKey('answer_keys'), isFalse);
    });

    test('completion reports how much of the funnel was answered', () async {
      await service.logOnboardingCompleted(total: 9, answered: 7);

      expect(analytics.events.single.name, 'onboarding_completed');
      expect(analytics.events.single.parameters, {'step_count': 9, 'answered_count': 7});
    });
  });
}
