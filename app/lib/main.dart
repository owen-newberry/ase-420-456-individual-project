import 'package:flutter/material.dart';
import 'screens/dayView.dart';
import 'screens/logEntry.dart';
import 'screens/sign_up.dart';
import 'screens/select_role.dart';
import 'screens/trainer_dashboard.dart';
// Dev helper: set to true to bypass sign-in and open DayView with a test athlete id.
// Set to false so app opens the sign-in/sign-up flow by default.
const bool kBypassSignIn = false;
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
  home: kBypassSignIn ? DayView(athleteId: kDevAthleteId) : const SelectRoleScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/day') {
          final args = settings.arguments as Map<String, dynamic>?;
          final athleteId = args != null ? args['athleteId'] as String? : null;
          return MaterialPageRoute(builder: (_) => DayView(athleteId: athleteId ?? ''));
        }
        if (settings.name == '/trainer') {
          final args = settings.arguments as Map<String, dynamic>?;
          final trainerId = args != null ? args['trainerId'] as String? : null;
          if (trainerId == null) return null;
          return MaterialPageRoute(builder: (_) => TrainerDashboard(trainerId: trainerId));
        }
        if (settings.name == '/signup') {
          final args = settings.arguments as Map<String, dynamic>?;
          final role = args != null ? args['role'] as String? : null;
          return MaterialPageRoute(builder: (_) => SignUpScreen(initialRole: role));
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
