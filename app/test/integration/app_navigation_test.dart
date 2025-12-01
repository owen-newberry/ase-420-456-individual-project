import 'package:flutter_test/flutter_test.dart';
// no extra material import required for this simple widget test
import 'package:app/main.dart' as app;

void main() {
  testWidgets('App navigation: select role -> sign in screen', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // We should be on the SelectRoleScreen
    expect(find.text('Choose role'), findsOneWidget);

    // Tap 'Log in as athlete' and verify Sign In screen appears
    final athleteBtn = find.text('Log in as athlete');
    expect(athleteBtn, findsOneWidget);
    await tester.tap(athleteBtn);
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });
}
