import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/database_service.dart';

/// Day view — shows today's workout plan and lets user tap exercises to log.
class DayView extends StatefulWidget {
  const DayView({Key? key}) : super(key: key);

  @override
  _DayViewState createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  final DatabaseService _db = DatabaseService();
  DateTime _selected = DateTime.now();
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  void _loadPlan() async {
    final date = _selected.toIso8601String().substring(0, 10);
    try {
      final plans = await _db.fetchPlansForDate(date);
      if (!mounted) return;
      setState(() => _plans = plans);
    } catch (e) {
      if (!mounted) return;
      setState(() => _plans = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Today\'s Workout'),
      ),
      body: Column(
        children: [
          ListTile(
            title: Text('Selected date: ${_selected.toLocal().toIso8601String().substring(0, 10)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _selected,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) {
                setState(() => _selected = d);
                _loadPlan();
              }
            },
          ),
          Expanded(
            child: () {
              final items = <Map<String, dynamic>>[];
              for (final p in _plans) {
                var exercises = p['exercises'];
                if (exercises is String) {
                  try {
                    final parsed = jsonDecode(exercises);
                    if (parsed is List) exercises = parsed;
                  } catch (_) {}
                }
                if (exercises is List) {
                  for (final e in exercises) {
                    items.add({
                      'planId': p['id'],
                      'planDate': p['date'],
                      'exercise': e,
                    });
                  }
                }
              }

              if (items.isEmpty) return const Center(child: Text('No plan for this day'));

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final ex = item['exercise'];
                  final exName = (ex is Map) ? (ex['name'] ?? ex['id'] ?? ex).toString() : ex.toString();
                  final sets = (ex is Map && ex['sets'] != null) ? ex['sets'].toString() : '';
                  final reps = (ex is Map && ex['reps'] != null) ? ex['reps'].toString() : '';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: ListTile(
                      title: Text(exName),
                      subtitle: Text('${sets.isNotEmpty ? 'Sets: $sets' : ''}${reps.isNotEmpty ? ' • Reps: $reps' : ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pushNamed('/log', arguments: {
                          'planId': item['planId'],
                          'exerciseId': (ex is Map) ? (ex['id'] ?? ex['name'] ?? ex) : ex,
                          'exercise': ex,
                        }).then((_) => _loadPlan());
                      },
                    ),
                  );
                },
              );
            }(),
          ),
        ],
      ),
    );
  }
}
