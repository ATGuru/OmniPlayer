import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/features/about/about_screen.dart';

void main() {
  testWidgets('about screen names the maker and the company', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

    expect(find.textContaining('Guru Morgan'), findsOneWidget);
    expect(find.textContaining('AllTechGuru'), findsWidgets);
    expect(find.textContaining('Missouri'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('The Frequency'), 200);
    expect(find.text('The Frequency'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Privacy policy'), 200);
    expect(find.text('Privacy policy'), findsOneWidget);
  });
}
