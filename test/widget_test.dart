// Minimal widget smoke test to ensure the test harness runs without
// requiring app Providers or Firebase initialization.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke: renders a basic widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('SMOKE_OK')),
        ),
      ),
    );

    expect(find.text('SMOKE_OK'), findsOneWidget);
  });
}
