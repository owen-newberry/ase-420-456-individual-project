import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/screens/logEntry.dart';

void main() {
  testWidgets('LogEntry pre-fills from SharedPreferences cache', (WidgetTester tester) async {
    // Arrange: mock shared preferences with a cached last_log entry
    final athleteId = 'athX';
    final exerciseId = 'exY';
    final key = 'last_log_${athleteId}_$exerciseId';
    final cachedSets = jsonEncode([
      {'weight': 55.0, 'reps': 5, 'notes': '', 'timestamp': DateTime.now().toIso8601String()},
      {'weight': 60.0, 'reps': 5, 'notes': '', 'timestamp': DateTime.now().toIso8601String()},
    ]);
    SharedPreferences.setMockInitialValues({key: cachedSets, 'pb_user_id': athleteId});

    // Build the LogEntry screen
    await tester.pumpWidget(MaterialApp(home: LogEntryScreen(athleteId: athleteId, planId: 'plan1', exerciseId: exerciseId)));

    // Allow async init to complete
    await tester.pumpAndSettle();

    // Find TextFields and assert their controller values reflect cached weights
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    final tf1 = tester.widgetList<TextField>(fields).first;
    final tf2 = tester.widgetList<TextField>(fields).skip(1).first;
    expect(tf1.controller?.text, '55.0');
    expect(tf2.controller?.text, '60.0');
  });
}
