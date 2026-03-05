import 'package:flutter/material.dart';
import 'utils/route_observer.dart';
import 'screens/home.dart';
import 'screens/logEntry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ForgeWorkoutApp());
}

class ForgeWorkoutApp extends StatelessWidget {
  const ForgeWorkoutApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Forge Workout brand colors
    const brandWhite = Color(0xFFFFFFFF);
    const brandBlack = Color(0xFF1A1A2E);
    const brandAccent = Color(0xFFE94560);
    const brandGray = Color(0xFF9E9E9E);

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: brandAccent,
      onPrimary: brandWhite,
      secondary: brandGray,
      onSecondary: brandBlack,
      error: Colors.red.shade700,
      onError: brandWhite,
      surface: brandWhite,
      onSurface: brandBlack,
    );

    final theme = ThemeData(
      colorScheme: colorScheme,
      primaryColor: brandAccent,
      scaffoldBackgroundColor: brandWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandBlack,
        foregroundColor: brandWhite,
        elevation: 2,
        titleTextStyle: TextStyle(color: brandWhite, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandAccent,
          foregroundColor: brandWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandAccent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brandWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: brandGray)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: brandGray)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: brandAccent)),
        labelStyle: const TextStyle(color: brandBlack),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brandBlack,
        indicatorColor: brandAccent.withOpacity(0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: brandAccent);
          }
          return IconThemeData(color: brandWhite.withOpacity(0.7));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: brandAccent, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: brandWhite.withOpacity(0.7), fontSize: 12);
        }),
      ),
      dividerColor: brandGray,
      cardColor: brandWhite,
    );

    return MaterialApp(
      title: 'Forge Workout',
      theme: theme,
      navigatorObservers: [routeObserver],
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/log') {
          final args = settings.arguments as Map<String, dynamic>?;
          final planId = args?['planId'] as String? ?? '';
          final exerciseId = args?['exerciseId'] as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => LogEntryScreen(
              planId: planId,
              exerciseId: exerciseId,
              exercise: args?['exercise'] as Map<String, dynamic>?,
            ),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
