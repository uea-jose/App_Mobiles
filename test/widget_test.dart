// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_3/main.dart';

void main() {
  testWidgets('Shows login when onboarding is completed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'auth_token': '',
    });

    await tester.pumpWidget(const EssenzaApp());
    await tester.pumpAndSettle();

    expect(
      find.text('Inicia sesión para administrar tu tienda'),
      findsOneWidget,
    );
    expect(find.text('Entrar'), findsOneWidget);
  });
}
