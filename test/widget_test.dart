import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gateway/main.dart';

void main() {
  testWidgets('Gateway app displays the SMS dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('SMS Gateway'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Buy From Lango logo'), findsOneWidget);
    expect(find.text('Gateway status'), findsOneWidget);
    expect(find.text('Vivo background settings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Outbound delivery report'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Outbound delivery report'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recent SMS activity'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recent SMS activity'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
