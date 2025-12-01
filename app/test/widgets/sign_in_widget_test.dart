import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/screens/sign_in.dart';

void main() {
  testWidgets('SignInScreen shows fields and trainer create account', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SignInScreen(role: 'trainer')));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    // trainer should see 'Create an account' TextButton
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('SignInScreen athlete role hides create account', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SignInScreen(role: 'athlete')));
    await tester.pumpAndSettle();
    expect(find.text('Create an account'), findsNothing);
  });
}
