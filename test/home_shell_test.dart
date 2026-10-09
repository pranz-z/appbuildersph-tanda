import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/ui/home_shell.dart';

void main() {
  testWidgets('shell shows three tabs and switches between them',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));

    expect(find.text('Tala'), findsWidgets);
    expect(find.text('Tanong'), findsOneWidget);
    expect(find.text('Nakabinbin'), findsOneWidget);
    expect(find.textContaining('Locality meter'), findsOneWidget);

    await tester.tap(find.text('Nakabinbin'));
    await tester.pumpAndSettle();
    expect(find.text('Open loops'), findsOneWidget);
  });
}
