import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Local SQLite database service for Forge Workout.
/// Replaces PocketBase with a fully offline, on-device database.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const _uuid = Uuid();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'forge_workout.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE plans (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            exercises TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE logs (
            id TEXT PRIMARY KEY,
            plan_id TEXT,
            exercise_id TEXT NOT NULL,
            sets TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (plan_id) REFERENCES plans(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE templates (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            exercises TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        // Create indexes for common queries
        await db.execute('CREATE INDEX idx_plans_date ON plans(date)');
        await db.execute('CREATE INDEX idx_logs_exercise ON logs(exercise_id)');
        await db.execute('CREATE INDEX idx_logs_plan ON logs(plan_id)');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Plans
  // ---------------------------------------------------------------------------

  /// Fetch all plans for a specific date (YYYY-MM-DD).
  Future<List<Map<String, dynamic>>> fetchPlansForDate(String date) async {
    final db = await database;
    final results = await db.query('plans', where: 'date = ?', whereArgs: [date]);
    return results.map((row) {
      final m = Map<String, dynamic>.from(row);
      // Parse exercises JSON string back to a list
      if (m['exercises'] is String) {
        try {
          m['exercises'] = jsonDecode(m['exercises'] as String);
        } catch (_) {
          m['exercises'] = [];
        }
      }
      return m;
    }).toList();
  }

  /// Fetch all plans (no date filter).
  Future<List<Map<String, dynamic>>> fetchAllPlans() async {
    final db = await database;
    final results = await db.query('plans', orderBy: 'date DESC');
    return results.map((row) {
      final m = Map<String, dynamic>.from(row);
      if (m['exercises'] is String) {
        try {
          m['exercises'] = jsonDecode(m['exercises'] as String);
        } catch (_) {
          m['exercises'] = [];
        }
      }
      return m;
    }).toList();
  }

  /// Create a new plan.
  Future<Map<String, dynamic>> createPlan(String date, List<dynamic> exercises) async {
    final db = await database;
    final id = _uuid.v4();
    final exercisesJson = jsonEncode(exercises);
    final now = DateTime.now().toIso8601String();

    await db.insert('plans', {
      'id': id,
      'date': date,
      'exercises': exercisesJson,
      'created_at': now,
    });

    return {
      'id': id,
      'date': date,
      'exercises': exercises,
      'created_at': now,
    };
  }

  /// Update an existing plan.
  Future<Map<String, dynamic>> updatePlan(String planId, Map<String, dynamic> updates) async {
    final db = await database;
    final updatesCopy = Map<String, dynamic>.from(updates);

    // Serialize exercises to JSON string if present
    if (updatesCopy.containsKey('exercises')) {
      final ex = updatesCopy['exercises'];
      if (ex is! String) {
        updatesCopy['exercises'] = jsonEncode(ex);
      }
    }

    await db.update('plans', updatesCopy, where: 'id = ?', whereArgs: [planId]);

    return await getPlanById(planId);
  }

  /// Delete a plan.
  Future<void> deletePlan(String planId) async {
    final db = await database;
    await db.delete('plans', where: 'id = ?', whereArgs: [planId]);
  }

  /// Get a plan by id.
  Future<Map<String, dynamic>> getPlanById(String id) async {
    final db = await database;
    final results = await db.query('plans', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) throw Exception('Plan not found: $id');
    final m = Map<String, dynamic>.from(results.first);
    if (m['exercises'] is String) {
      try {
        m['exercises'] = jsonDecode(m['exercises'] as String);
      } catch (_) {
        m['exercises'] = [];
      }
    }
    return m;
  }

  // ---------------------------------------------------------------------------
  // Logs
  // ---------------------------------------------------------------------------

  /// Create a workout log.
  Future<Map<String, dynamic>> createLog(String planId, String exerciseId, List<Map<String, dynamic>> sets) async {
    final db = await database;
    final id = _uuid.v4();
    final setsJson = jsonEncode(sets);
    final now = DateTime.now().toIso8601String();

    await db.insert('logs', {
      'id': id,
      'plan_id': planId,
      'exercise_id': exerciseId,
      'sets': setsJson,
      'created_at': now,
    });

    return {
      'id': id,
      'plan_id': planId,
      'exercise_id': exerciseId,
      'sets': sets,
      'created_at': now,
    };
  }

  /// Fetch logs for a specific exercise, optionally filtered by plan. Returns most recent first.
  Future<List<Map<String, dynamic>>> fetchLogsForExercise(String exerciseId, {String? planId, int limit = 20}) async {
    final db = await database;
    String where = 'exercise_id = ?';
    List<dynamic> args = [exerciseId];
    if (planId != null && planId.isNotEmpty) {
      where += ' AND plan_id = ?';
      args.add(planId);
    }
    final results = await db.query(
      'logs',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((row) {
      final m = Map<String, dynamic>.from(row);
      if (m['sets'] is String) {
        try {
          m['sets'] = jsonDecode(m['sets'] as String);
        } catch (_) {
          m['sets'] = [];
        }
      }
      return m;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Templates
  // ---------------------------------------------------------------------------

  /// Fetch all templates.
  Future<List<Map<String, dynamic>>> fetchAllTemplates() async {
    final db = await database;
    final results = await db.query('templates', orderBy: 'created_at DESC');
    return results.map((row) {
      final m = Map<String, dynamic>.from(row);
      if (m['exercises'] is String) {
        try {
          m['exercises'] = jsonDecode(m['exercises'] as String);
        } catch (_) {
          m['exercises'] = [];
        }
      }
      return m;
    }).toList();
  }

  /// Create a template.
  Future<Map<String, dynamic>> createTemplate(String name, List<dynamic> exercises) async {
    final db = await database;
    final id = _uuid.v4();
    final exercisesJson = jsonEncode(exercises);
    final now = DateTime.now().toIso8601String();

    await db.insert('templates', {
      'id': id,
      'name': name,
      'exercises': exercisesJson,
      'created_at': now,
    });

    return {
      'id': id,
      'name': name,
      'exercises': exercises,
      'created_at': now,
    };
  }

  /// Update a template.
  Future<Map<String, dynamic>> updateTemplate(String templateId, Map<String, dynamic> updates) async {
    final db = await database;
    final updatesCopy = Map<String, dynamic>.from(updates);

    if (updatesCopy.containsKey('exercises')) {
      final ex = updatesCopy['exercises'];
      if (ex is! String) {
        updatesCopy['exercises'] = jsonEncode(ex);
      }
    }

    await db.update('templates', updatesCopy, where: 'id = ?', whereArgs: [templateId]);
    return await getTemplateById(templateId);
  }

  /// Delete a template.
  Future<void> deleteTemplate(String templateId) async {
    final db = await database;
    await db.delete('templates', where: 'id = ?', whereArgs: [templateId]);
  }

  /// Get a template by id.
  Future<Map<String, dynamic>> getTemplateById(String id) async {
    final db = await database;
    final results = await db.query('templates', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) throw Exception('Template not found: $id');
    final m = Map<String, dynamic>.from(results.first);
    if (m['exercises'] is String) {
      try {
        m['exercises'] = jsonDecode(m['exercises'] as String);
      } catch (_) {
        m['exercises'] = [];
      }
    }
    return m;
  }

  /// Apply a template by creating plan records for each matching day over N weeks.
  Future<void> applyTemplate(String templateId, DateTime startDate, int weeks) async {
    final tpl = await getTemplateById(templateId);
    final exercisesRaw = tpl['exercises'];
    List<dynamic> exercises;
    if (exercisesRaw is String) {
      exercises = jsonDecode(exercisesRaw) as List<dynamic>;
    } else if (exercisesRaw is List) {
      exercises = exercisesRaw;
    } else {
      exercises = [];
    }

    final anyHasDay = exercises.any((e) => e is Map && e.containsKey('day'));
    final totalDays = weeks * 7;

    for (var i = 0; i < totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T').first;
      // DateTime.weekday: Mon=1..Sun=7 -> map to Sun=0..Sat=6
      final dayIndex = date.weekday % 7;

      List<dynamic> todays = [];
      if (anyHasDay) {
        for (final e in exercises) {
          try {
            if (e is Map) {
              final rawDay = e['day'];
              if (rawDay == null) continue;
              int? d;
              if (rawDay is int) {
                d = rawDay;
              } else {
                d = int.tryParse(rawDay.toString());
              }
              if (d != null && d == dayIndex) todays.add(e);
            }
          } catch (_) {}
        }
      } else {
        if ((i % 7) == 0) {
          todays = List<dynamic>.from(exercises);
        }
      }

      if (todays.isNotEmpty) {
        await createPlan(dateStr, todays);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Normalize helpers (ported from old PocketBaseService)
  // ---------------------------------------------------------------------------

  /// Normalize a `sets` field into a List<Map> with numeric `weight` values.
  List<Map<String, dynamic>> normalizeSetsField(dynamic setsRaw) {
    List<dynamic> parsed = [];
    if (setsRaw == null) return <Map<String, dynamic>>[];

    dynamic working = setsRaw;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (working is List) {
        parsed = working;
        break;
      }
      if (working is String) {
        try {
          var candidate = working.trim();
          candidate = candidate.replaceAll(RegExp(r'\u00A0'), '');
          if (candidate.contains('.') && candidate.contains(',')) {
            final lastDot = candidate.lastIndexOf('.');
            final lastComma = candidate.lastIndexOf(',');
            if (lastComma > lastDot) {
              candidate = candidate.replaceAll('.', '');
              candidate = candidate.replaceAll(',', '.');
            } else {
              candidate = candidate.replaceAll(',', '');
            }
          } else if (candidate.contains(',') && !candidate.contains('.')) {
            candidate = candidate.replaceAll(',', '.');
          }
          final p = jsonDecode(candidate);
          working = p;
          if (working is List) {
            parsed = working;
            break;
          }
        } catch (_) {
          working = null;
          break;
        }
      } else {
        break;
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final s in parsed) {
      try {
        if (s is Map) {
          final m = Map<String, dynamic>.from(s);
          var wraw = m['weight'];
          double? w;
          if (wraw is num) {
            w = wraw.toDouble();
          } else {
            var wstr = (wraw ?? '').toString().trim();
            wstr = wstr.replaceAll(RegExp(r'\u00A0'), '');
            if (wstr.contains(',') && wstr.contains('.')) {
              final lastDot = wstr.lastIndexOf('.');
              final lastComma = wstr.lastIndexOf(',');
              if (lastComma > lastDot) {
                wstr = wstr.replaceAll('.', '');
                wstr = wstr.replaceAll(',', '.');
              } else {
                wstr = wstr.replaceAll(',', '');
              }
            } else if (wstr.contains(',') && !wstr.contains('.')) {
              wstr = wstr.replaceAll(',', '.');
            }
            w = double.tryParse(wstr);
          }
          if (w != null) m['weight'] = w;
          out.add(m);
        }
      } catch (_) {}
    }
    return out;
  }

  /// Close the database (for cleanup/testing).
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
