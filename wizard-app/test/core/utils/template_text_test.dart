import 'package:flutter_test/flutter_test.dart';
import 'package:appwizard/core/utils/template_text.dart';

void main() {
  group('TemplateText.fill', () {
    test('replaces known placeholders and leaves unknown ones visible', () {
      expect(
        TemplateText.fill('Studying {platform} sellers… {missing}', {'platform': 'eBay'}),
        'Studying eBay sellers… {missing}',
      );
    });

    test('null values are left as placeholders', () {
      expect(TemplateText.fill('{a} {b}', {'a': 'x', 'b': null}), 'x {b}');
    });
  });

  group('TemplateText.fillHighlightKeys', () {
    test('fills placeholder keys so highlights match rendered text', () {
      final out = TemplateText.fillHighlightKeys(
        {'{monthly_leak}': '#C47A00', 'Studies reveal:': 'bold'},
        {'monthly_leak': '\$550'},
      );
      expect(out, {'\$550': '#C47A00', 'Studies reveal:': 'bold'});
    });

    test('non-map input returns null', () {
      expect(TemplateText.fillHighlightKeys(['a'], {}), isNull);
    });
  });
}
