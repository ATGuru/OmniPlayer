import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/main.dart';
import 'package:omniplayer/core/theme/app_theme.dart';

Future<void> _pumpApp(WidgetTester tester) {
  return tester.pumpWidget(const OmniPlayerApp(home: SizedBox.shrink()));
}

void main() {
  testWidgets('OmniPlayerApp has correct theme', (WidgetTester tester) async {
    await _pumpApp(tester);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme, isNotNull);
    expect(materialApp.theme!.brightness, equals(Brightness.dark));
    expect(materialApp.theme!.scaffoldBackgroundColor, equals(OmniPlayerColors.voidBlack));
  });

  testWidgets('OmniPlayerApp has debug banner disabled', (WidgetTester tester) async {
    await _pumpApp(tester);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
  });

  testWidgets('OmniPlayerApp has correct title', (WidgetTester tester) async {
    await _pumpApp(tester);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, equals('OmniPlayer'));
  });
}
