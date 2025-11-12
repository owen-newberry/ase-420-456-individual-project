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
    // DNA Sports Center brand colors
    const brandWhite = Color(0xFFFFFFFF);
    const brandBlack = Color(0xFF000000);
    const brandRed = Color(0xFFCC0000);
    const brandGray = Color(0xFF9E9E9E);

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: brandRed,
      onPrimary: brandWhite,
      secondary: brandGray,
      onSecondary: brandBlack,
      error: Colors.red.shade700,
      onError: brandWhite,
      background: brandWhite,
      onBackground: brandBlack,
      surface: brandWhite,
      onSurface: brandBlack,
    );

    final theme = ThemeData(
      colorScheme: colorScheme,
      primaryColor: brandRed,
      scaffoldBackgroundColor: brandWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandBlack,
        foregroundColor: brandWhite,
        elevation: 2,
        titleTextStyle: TextStyle(color: brandWhite, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandRed,
          foregroundColor: brandWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandRed),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brandWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: brandGray)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: brandGray)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: brandRed)),
        labelStyle: TextStyle(color: brandBlack),
      ),
      dividerColor: brandGray,
  cardColor: brandWhite,
    );

    return MaterialApp(
      title: 'DNA Sports Center',
      theme: theme,
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
