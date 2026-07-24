import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deliveryapp/delivery_dashboard_page.dart';
import 'package:deliveryapp/main.dart';

void main() {
  testWidgets('OrderX login portal renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('OrderX'), findsOneWidget);
    expect(find.text('DELIVERY TEAM PORTAL'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('Password visibility toggle changes icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('Delivery dashboard renders customer selection UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DeliveryDashboardPage(userName: 'Alex', accessToken: 'token'),
      ),
    );

    expect(find.text('OrderX Delivery'), findsOneWidget);
    expect(find.text('Hello, Alex'), findsOneWidget);
    expect(find.text('Search Customer'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);
  });
}
