import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:blendjam/main.dart';

void main() {
  testWidgets('BlendJam renders both decks and Auto Mix control',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DJ()));
    await tester.pump();

    expect(find.text('BlendJam'), findsOneWidget);
    expect(find.textContaining('DECK A'), findsOneWidget);
    expect(find.textContaining('DECK B'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
  });
}
