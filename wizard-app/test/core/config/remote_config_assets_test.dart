import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every asset the bundled Remote Config template names has to be in the app.
///
/// The templates are strings of JSON inside a JSON file, so a renamed or missing file is
/// invisible until the screen that needs it renders nothing. This walks every value in every
/// template and checks the ones that look like asset paths, which is the only place that
/// catches a typo in a screen no test pumps.
void main() {
  late Map<String, dynamic> defaults;

  setUpAll(() {
    defaults = jsonDecode(
      File('assets/config/remote_config_defaults.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  /// Asset-looking strings found anywhere in [node], with the path that led to each.
  Map<String, String> assetPaths(Object? node, [String trail = '']) {
    final found = <String, String>{};
    if (node is String) {
      if (node.startsWith('assets/')) found[node] = trail;
      // A template is itself a JSON string; walk into it.
      if (node.trimLeft().startsWith('{') || node.trimLeft().startsWith('[')) {
        try {
          found.addAll(assetPaths(jsonDecode(node), trail));
        } on FormatException {
          // not a template, just text
        }
      }
    } else if (node is Map) {
      node.forEach((k, v) => found.addAll(assetPaths(v, '$trail/$k')));
    } else if (node is List) {
      for (var i = 0; i < node.length; i++) {
        found.addAll(assetPaths(node[i], '$trail[$i]'));
      }
    }
    return found;
  }

  test('every asset the templates name exists', () {
    final missing = <String>[];
    assetPaths(defaults).forEach((path, trail) {
      if (!File(path).existsSync()) missing.add('$path (at $trail)');
    });
    expect(missing, isEmpty);
  });

  test('and sits in a folder pubspec bundles', () {
    final bundled = RegExp(r'^assets/(config|images|lottie|fonts)/');
    final strays = assetPaths(defaults).keys.where((p) => !bundled.hasMatch(p)).toList();
    expect(strays, isEmpty, reason: 'pubspec declares config, images, lottie and fonts only');
  });

  test('the walk actually found the assets it should', () {
    final paths = assetPaths(defaults).keys.toSet();
    // A smoke check on the walk itself: if the nested-template decoding broke, this empties
    // out and the two tests above would pass while checking nothing.
    expect(paths.length, greaterThan(10));
    expect(paths, contains('assets/images/wizard_yes_cutout.png'));
    expect(paths.any((p) => p.endsWith('.json')), isTrue);
  });
}
