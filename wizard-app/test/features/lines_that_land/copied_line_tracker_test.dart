import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/lines_that_land/data/mappers/lines_that_land_mapper.dart';
import 'package:appwizard/features/lines_that_land/data/models/lines_that_land_response.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/lines_that_land/presentation/utils/copied_line_tracker.dart';

/// Fake scheduler: records callbacks so the test can fire them deterministically.
class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;

  void fire() {
    if (!cancelled) callback();
  }
}

void main() {
  group('CopiedLineTracker', () {
    late List<_FakeTimer> timers;
    late CopiedLineTracker tracker;

    setUp(() {
      timers = [];
      tracker = CopiedLineTracker(
        hold: const Duration(milliseconds: 1200),
        scheduler: (d, cb) {
          final t = _FakeTimer(d, cb);
          timers.add(t);
          return t;
        },
      );
    });

    tearDown(() => tracker.dispose());

    test('keyFor is stable per category + index', () {
      expect(CopiedLineTracker.keyFor('opening', 1), 'opening#1');
      expect(CopiedLineTracker.keyFor('opening', 1), CopiedLineTracker.keyFor('opening', 1));
      expect(CopiedLineTracker.keyFor('opening', 1), isNot(CopiedLineTracker.keyFor('closing', 1)));
    });

    test('markCopied highlights one line and reverts after the hold', () {
      var notifications = 0;
      tracker.addListener(() => notifications++);

      tracker.markCopied('opening#0');
      expect(tracker.isCopied('opening#0'), isTrue);
      expect(tracker.isCopied('opening#1'), isFalse);
      expect(notifications, 1);
      expect(timers.single.duration, const Duration(milliseconds: 1200));

      timers.single.fire();
      expect(tracker.copiedKey, isNull);
      expect(notifications, 2);
    });

    test('copying another line moves the highlight and cancels the old revert', () {
      tracker.markCopied('a');
      tracker.markCopied('b');
      expect(tracker.isCopied('a'), isFalse);
      expect(tracker.isCopied('b'), isTrue);
      expect(timers[0].cancelled, isTrue);

      // A stale timer must not clear a newer highlight.
      timers[0].fire();
      expect(tracker.isCopied('b'), isTrue);
      timers[1].fire();
      expect(tracker.copiedKey, isNull);
    });

    test('clear resets immediately', () {
      tracker.markCopied('a');
      tracker.clear();
      expect(tracker.copiedKey, isNull);
      expect(timers.single.cancelled, isTrue);
    });
  });

  group('LinesThatLandMapper.toCategoryEntities', () {
    LinesCategoryDto dto(String id, String name, List<Object> tips) =>
        LinesCategoryDto.fromJson({'id': id, 'name': name, 'tips': tips});

    test('exposes every tip and a day-rotated daily tip, dropping unusable categories', () {
      final mapper = LinesThatLandMapper();
      final dtos = [
        dto('opening', 'Opening lines', ['a', 'b', 'c']),
        dto('empty', 'Empty', []),
        dto('blank', 'Blank tips', ['  ', {'en': ''}]),
        dto('', 'Broken', ['x']),
      ];
      final day4 = mapper.toCategoryEntities(dtos, 4).single;
      expect(day4.id, 'opening');
      expect(day4.tips.map((t) => t.text.toJson()), ['a', 'b', 'c']);
      expect(day4.allTips.length, 3);
      expect(day4.dailyTip.text.toJson(), 'b');
      expect(mapper.toCategoryEntities(dtos, 0).single.dailyTip.text.toJson(), 'a');
    });

    test('keeps multilocale texts intact', () {
      final c = LinesThatLandMapper().toCategoryEntities([
        LinesCategoryDto.fromJson({
          'id': 'x',
          'name': {'en': 'X', 'es': 'Equis'},
          'tips': [{'en': 'only', 'es': 'solo'}],
        }),
      ], 7).single;
      expect(c.name.toJson(), {'en': 'X', 'es': 'Equis'});
      expect(c.allTips.single.text.toJson(), {'en': 'only', 'es': 'solo'});
    });

    test('hasText ignores blank strings and maps without any text', () {
      expect(LinesThatLandMapper.hasText(const MultilocaleText('hi')), isTrue);
      expect(LinesThatLandMapper.hasText(const MultilocaleText('  ')), isFalse);
      expect(LinesThatLandMapper.hasText(const MultilocaleText({'en': '', 'es': 'hola'})), isTrue);
      expect(LinesThatLandMapper.hasText(const MultilocaleText({'en': ''})), isFalse);
    });
  });
}
