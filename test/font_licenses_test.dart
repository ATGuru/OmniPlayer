import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/core/theme/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Orbitron and Rajdhani appear on the licenses page', () async {
    registerFontLicenses();
    final found = <String, String>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        if (package == 'Orbitron' || package == 'Rajdhani') {
          found[package] = entry.paragraphs.map((paragraph) => paragraph.text).join('\n');
        }
      }
    }
    expect(found.keys, containsAll(['Orbitron', 'Rajdhani']));
    expect(found['Orbitron'], contains('SIL Open Font License'));
    expect(found['Orbitron'], contains('Reserved Font Name: "Orbitron"'));
    expect(found['Rajdhani'], contains('Indian Type Foundry'));
    expect(found['Rajdhani'], contains('SIL Open Font License'));
  });
}
