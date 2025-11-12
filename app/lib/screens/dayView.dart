import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import '../widgets/account_action.dart';

class DayView extends StatefulWidget {
  final String athleteId;

  const DayView({Key? key, required this.athleteId}) : super(key: key);

  @override
  _DayViewState createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  final PocketBaseService _pb = PocketBaseService();
  DateTime _selected = DateTime.now();
  List<dynamic> _plan = [];
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _loadProfile();
  }

  void _loadPlan() async {
    final date = _selected.toIso8601String().substring(0,10);
    try {
      final plans = await _pb.fetchPlanForDate(widget.athleteId, date);
      if (!mounted) return;
      // If backend has no plans for this day, provide a small local sample
      // so designers can preview the UI quickly.
      if (plans.isEmpty) {
        setState(() => _plan = _samplePlan(date));
      } else {
        setState(() => _plan = plans);
      }
    } catch (e) {
      if (!mounted) return;
      // Avoid showing a SnackBar here because _loadPlan may run during
      // initState before the Scaffold is fully laid out which can trigger
      // layout exceptions on some platforms. Fall back to local sample data
      // so designers can continue to preview the UI.
      setState(() => _plan = _samplePlan(date));
    }
  }

  List<dynamic> _samplePlan(String date) {
    return [
      {
        'id': 'sample-plan-1',
        'date': date,
        'title': 'Full Body Strength',
        'exercises': [
          { 'id': 'ex-1', 'name': 'Back Squat', 'sets': 5, 'reps': '5' },
          { 'id': 'ex-2', 'name': 'Bench Press', 'sets': 5, 'reps': '5' },
          { 'id': 'ex-3', 'name': 'Romanian Deadlift', 'sets': 3, 'reps': '8' },
        ]
      }
    ];
  }

  void _loadProfile() async {
    try {
      final user = await _pb.getUserById(widget.athleteId);
      if (!mounted) return;
      setState(() => _displayName = (user['displayName'] ?? '').toString());
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Day View'), actions: [
        Padding(padding: const EdgeInsets.only(right: 8.0), child: AccountAction(displayName: _displayName)),
      ]),
      body: Column(
        children: [
          ListTile(
            title: Text('Selected date: ${_selected.toLocal().toIso8601String().substring(0,10)}'),
            trailing: Icon(Icons.calendar_today),
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
              // Flatten plans -> exercises so each exercise appears as its own card.
              final items = <Map<String, dynamic>>[];
              for (final p in _plan) {
                final exercises = p['exercises'];
                if (exercises is List) {
                  for (final e in exercises) {
                    items.add({
                      'planId': p['id'],
                      'planTitle': p['title'] ?? p['date'],
                      'exercise': e,
                    });
                  }
                }
              }

              if (items.isEmpty) return Center(child: Text('No plan for this day'));

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final ex = item['exercise'];
                  final exName = (ex is Map) ? (ex['name'] ?? ex['id'] ?? ex).toString() : ex.toString();
                  final sets = (ex is Map && ex['sets'] != null) ? ex['sets'].toString() : '';
                  return Card(
                    child: ListTile(
                      title: Text(exName),
                      subtitle: Text('${item['planTitle'] ?? ''}${sets.isNotEmpty ? ' • sets: $sets' : ''}'),
                      onTap: () {
                              Navigator.of(context).pushNamed('/log', arguments: {
                                'athleteId': widget.athleteId,
                                'planId': item['planId'],
                                'exerciseId': (ex is Map) ? (ex['id'] ?? ex['name'] ?? ex) : ex,
                                'exercise': ex,
                              });
                      },
                    ),
                  );
                },
              );
            }(),
          )
        ],
      ),
    );
  }
}
