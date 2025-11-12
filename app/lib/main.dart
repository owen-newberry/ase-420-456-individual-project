import 'package:flutter/material.dart';
import 'screens/dayView.dart';
import 'screens/logEntry.dart';
import 'screens/sign_in.dart';
import 'screens/sign_up.dart';
// Dev helper: set to true to bypass sign-in and open DayView with a test athlete id.
const bool kBypassSignIn = true;
const String kDevAthleteId = 'dev-athlete-id-0001';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DNA Sports Center',
      theme: ThemeData(primarySwatch: Colors.blue),
  home: kBypassSignIn ? DayView(athleteId: kDevAthleteId) : const SignInScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/day') {
          final args = settings.arguments as Map<String, dynamic>?;
          final athleteId = args != null ? args['athleteId'] as String? : null;
          return MaterialPageRoute(builder: (_) => DayView(athleteId: athleteId ?? ''));
        }
        if (settings.name == '/signup') {
          return MaterialPageRoute(builder: (_) => const SignUpScreen());
        }
        if (settings.name == '/log') {
          final args = settings.arguments as Map<String, dynamic>?;
          final athleteId = args?['athleteId'] as String? ?? '';
          final planId = args?['planId'] as String? ?? '';
          final exerciseId = args?['exerciseId'] as String? ?? '';
          return MaterialPageRoute(builder: (_) => LogEntryScreen(athleteId: athleteId, planId: planId, exerciseId: exerciseId, exercise: args?['exercise'] as Map<String,dynamic>?));
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
