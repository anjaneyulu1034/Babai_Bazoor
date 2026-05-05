// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:babai_bazor_app/app.dart';

void main() {
  testWidgets('shows splash branding', (WidgetTester tester) async {
    await tester.pumpWidget(const BabaiBazorApp());

    expect(find.text('Babai Bazor'), findsOneWidget);
    expect(find.text('Fresh Groceries Delivered'), findsOneWidget);
  });
}
