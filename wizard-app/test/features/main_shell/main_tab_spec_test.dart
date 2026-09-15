import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/main_shell/domain/main_tab.dart';
import 'package:appwizard/features/main_shell/domain/main_tab_spec.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

void main() {
  group('MainTab.fromId', () {
    test('maps known ids', () {
      expect(MainTab.fromId('home'), MainTab.home);
      expect(MainTab.fromId('lines'), MainTab.lines);
      expect(MainTab.fromId('history'), MainTab.history);
      expect(MainTab.fromId('profile'), MainTab.profile);
    });

    test('falls back for unknown / null ids', () {
      expect(MainTab.fromId('nope'), MainTab.home);
      expect(MainTab.fromId(null), MainTab.home);
      expect(MainTab.fromId('nope', fallback: MainTab.lines), MainTab.lines);
    });
  });

  group('MainTabSpec.resolve', () {
    const defaultOrder = [MainTab.home, MainTab.lines, MainTab.history, MainTab.profile];

    test('default order when config is missing or empty', () {
      expect(MainTabSpec.resolve(null).map((t) => t.tab), defaultOrder);
      expect(MainTabSpec.resolve(const <MainTabInput>[]).map((t) => t.tab), defaultOrder);
      for (final spec in MainTabSpec.resolve(null)) {
        expect(spec.label, isNull);
        expect(spec.fallbackLabel, MainTabSpec.defaultLabels[spec.tab]);
      }
    });

    test('keeps remote order and labels (as sent in main_page_config.tabs)', () {
      final remote = <MainTabInput>[
        (id: 'lines', label: MultilocaleText.fromJson({'en': 'Lines', 'es': 'Líneas'})),
        (id: 'home', label: MultilocaleText.fromJson({'en': 'Home', 'es': 'Inicio'})),
        (id: 'profile', label: MultilocaleText.fromJson({'en': 'Profile', 'es': 'Perfil'})),
        (id: 'history', label: MultilocaleText.fromJson({'en': 'History', 'es': 'Historial'})),
      ];
      final specs = MainTabSpec.resolve(remote);
      expect(specs.map((t) => t.tab), [MainTab.lines, MainTab.home, MainTab.profile, MainTab.history]);
      expect(specs.first.label, isA<MultilocaleText>());
      expect(specs.first.label.toString(), contains('Líneas'));
      expect(specs.first, MainTabSpec(tab: MainTab.lines, label: remote.first.label));
    });

    test('drops unknown ids and duplicates, normalises case and whitespace', () {
      final specs = MainTabSpec.resolve(const <MainTabInput>[
        (id: 'Home', label: null),
        (id: 'settings', label: null),
        (id: 'home', label: 'Second home'),
        (id: ' lines ', label: null),
      ]);
      expect(specs.map((t) => t.tab), [MainTab.home, MainTab.lines]);
      expect(specs.first.label, isNull, reason: 'first occurrence wins');
    });

    test('falls back to defaults when no id is known', () {
      final specs = MainTabSpec.resolve(const <MainTabInput>[(id: 'a', label: null), (id: 'b', label: null)]);
      expect(specs.map((t) => t.tab), defaultOrder);
    });
  });
}
