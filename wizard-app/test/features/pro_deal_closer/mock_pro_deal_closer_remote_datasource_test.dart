import 'package:appwizard/features/conversation/domain/entities/deal_line.dart';
import 'package:appwizard/features/pro_deal_closer/data/datasources/pro_deal_closer_remote_datasource.dart';
import 'package:appwizard/features/pro_deal_closer/data/mappers/pro_deal_closer_mapper.dart';
import 'package:appwizard/features/pro_deal_closer/data/repositories/pro_deal_closer_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late MockProDealCloserRemoteDataSource source;

  setUp(() {
    source = MockProDealCloserRemoteDataSource(
      testLogger(),
      replyDelay: Duration.zero,
      optionsDelay: Duration.zero,
    );
  });

  test('replies per vibe match the prototype copy', () async {
    final friendly = await source.getReply(history: const [], vibe: 'friendly', locale: 'en');
    expect(
      friendly.text,
      "Nice find. Sellers usually list 15–25% above what they'll take, so a friendly \$140 with same-day pickup is a strong open. Want me to write it?",
    );
    final noNonsense = await source.getReply(history: const [], vibe: 'no_nonsense', locale: 'en');
    expect(noNonsense.text, startsWith('Open at \$140 cash, pickup today.'));
    final tactical = await source.getReply(history: const [], vibe: 'tactical', locale: 'en');
    expect(tactical.text, startsWith('Comparable Kallax units went for \$130–150 this week.'));
    final quiet = await source.getReply(history: const [], vibe: 'quiet_closer', locale: 'en');
    expect(quiet.text, startsWith('Keep it warm and low pressure'));
  });

  test('unknown vibe falls back to friendly', () async {
    final reply = await source.getReply(history: const [], vibe: 'unknown', locale: 'en');
    expect(reply.text, MockProDealCloserRemoteDataSource.replyTexts['friendly']);
  });

  test('redo appends the "(Regenerated)" suffix', () async {
    final reply = await source.getReply(
      history: const [],
      vibe: 'tactical',
      locale: 'en',
      regenerate: true,
    );
    expect(reply.text, endsWith(' (Regenerated)'));
  });

  test('options are three intent-tagged lines with why, per vibe', () async {
    for (final vibe in ['friendly', 'no_nonsense', 'tactical', 'quiet_closer']) {
      final options = await source.getOptions(history: const [], vibe: vibe, locale: 'en');
      expect(options, hasLength(3), reason: vibe);
      expect(options.map((o) => o.intent), ['opener', 'counter', 'close'], reason: vibe);
      expect(options.every((o) => o.why != null && o.why!.isNotEmpty), isTrue, reason: vibe);
    }
    final friendly = await source.getOptions(history: const [], vibe: 'friendly', locale: 'en');
    expect(
      friendly.first.text,
      'Hi! Is the Kallax still available? I could pick it up today if \$140 works for you.',
    );
  });

  test('repository maps DTOs to domain entities', () async {
    final repo = ProDealCloserRepositoryImpl(
      source,
      WizardReplyMapper(),
      DealOptionsMapper(),
      testLogger(),
    );

    final reply = await repo.getReply(history: const [], vibe: 'friendly', locale: 'en');
    expect(reply.isRight(), isTrue);

    final options = await repo.getOptions(history: const [], vibe: 'quiet_closer', locale: 'es');
    final lines = options.getOrElse(() => []);
    expect(lines.map((l) => l.intent), [DealIntent.opener, DealIntent.counter, DealIntent.close]);
    expect(lines.first.why, 'Low pressure, keeps rapport, still anchors low.');
  });
}
