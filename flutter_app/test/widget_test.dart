import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/screens/auth/auth_choice_screen.dart';

void main() {
  testWidgets(
    'UniSafe authentication screen loads',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthChoiceScreen(),
        ),
      );

      expect(
        find.text('Welcome to UniSafe'),
        findsOneWidget,
      );

      expect(
        find.text('Citizen Login'),
        findsOneWidget,
      );

      expect(
        find.text('Citizen Sign Up'),
        findsOneWidget,
      );

      expect(
        find.text('Authority Login'),
        findsOneWidget,
      );
    },
  );
}