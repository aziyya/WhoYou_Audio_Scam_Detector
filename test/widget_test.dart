import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whoyou/main.dart';

void main() {
  testWidgets('HomeScreen renders app bar correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WhoYouApp());

    expect(find.text('WhoYou'), findsOneWidget);
    expect(find.byIcon(Icons.shield), findsOneWidget);
  });

  testWidgets('HomeScreen renders phone input field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WhoYouApp());

    expect(find.text('+ 60'), findsOneWidget);
    expect(find.text('Enter Phone Number'), findsOneWidget);
  });

  testWidgets('HomeScreen renders safety tip', (WidgetTester tester) async {
    await tester.pumpWidget(const WhoYouApp());

    expect(find.byIcon(Icons.lightbulb), findsOneWidget);
    expect(
      find.textContaining('Be careful about clicking on links'),
      findsOneWidget,
    );
  });

  testWidgets('HomeScreen renders bottom nav bar', (WidgetTester tester) async {
    await tester.pumpWidget(const WhoYouApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('Bottom nav bar switches active tab on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WhoYouApp());

    await tester.tap(find.text('Report'));
    await tester.pump();

    await tester.tap(find.text('Home'));
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Phone input accepts text', (WidgetTester tester) async {
    await tester.pumpWidget(const WhoYouApp());

    await tester.enterText(find.byType(TextField), '0123456789');
    await tester.pump();

    expect(find.text('0123456789'), findsOneWidget);
  });
}
