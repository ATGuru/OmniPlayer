import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/features/onboarding/onboarding_dialog.dart';

void main() {
  testWidgets('next walks the guide and done closes it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showOnboarding(context),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR MUSIC'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('FREE MUSIC'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('ALBUMS AND PLAYLISTS'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('MAKE A SONG'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR MUSIC'), findsNothing);
  });
}
