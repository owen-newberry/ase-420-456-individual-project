import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _resolvedAthleteId;

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _loadProfile();
  }

  void _loadPlan() async {
    final date = _selected.toIso8601String().substring(0,10);
    String? athleteId = widget.athleteId;
    if (athleteId.isEmpty) {
      athleteId = await _pb.getCurrentUserId();
    }
    // store resolved athlete id for later navigation (avoid reading widget.athleteId again)
    if (mounted) setState(() => _resolvedAthleteId = athleteId);
    if (athleteId == null || athleteId.isEmpty) {
      // no athlete context — show empty (do not surface sample data)
      setState(() => _plan = []);
      return;
    }
    try {
      final plans = await _pb.fetchPlanForDate(athleteId, date);
      if (!mounted) return;
  if (plans.isEmpty) setState(() => _plan = []); else setState(() => _plan = plans);
    } catch (e) {
  if (!mounted) return;
  setState(() => _plan = []);
    }
  }

  // No sample plan — real data only

  void _loadProfile() async {
    try {
      String? athleteId = widget.athleteId;
      if (athleteId.isEmpty) athleteId = await _pb.getCurrentUserId();
      if (athleteId == null || athleteId.isEmpty) return;
      final user = await _pb.getUserById(athleteId);
      if (!mounted) return;
      setState(() => _displayName = (user['displayName'] ?? '').toString());
    } catch (e) {
      // ignore
    }
  }

  void _showDebugInfo() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('pb_token') ?? '<none>';
      final uid = sp.getString('pb_user_id') ?? '<none>';
      // attempt to fetch today's plans for the resolved user id (if present)
      String plansSummary = '<not fetched>';
      try {
        final resolved = _resolvedAthleteId ?? uid;
        if (resolved.isNotEmpty && resolved != '<none>') {
          final date = _selected.toIso8601String().split('T').first;
          final plans = await _pb.fetchPlanForDate(resolved, date);
          plansSummary = 'fetched ${plans.length} plans for $resolved on $date';
        } else {
          plansSummary = 'no resolved athlete id';
        }
      } catch (e) {
        plansSummary = 'fetch error: $e';
      }
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Auth debug'),
          content: Text('token: $token\nuserId: $uid\n$plansSummary'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Day View'),
        actions: [
          IconButton(
            tooltip: 'Debug auth',
            icon: const Icon(Icons.bug_report),
            onPressed: _showDebugInfo,
          ),
          Padding(padding: const EdgeInsets.only(right: 8.0), child: AccountAction(displayName: _displayName)),
        ],
      ),
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
                var exercises = p['exercises'];
                // PocketBase may store exercises as a JSON string in the record.
                if (exercises is String) {
                  try {
                    final parsed = jsonDecode(exercises);
                    if (parsed is List) exercises = parsed;
                  } catch (_) {
                    // leave as-is (will be ignored below)
                  }
                }
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
                                'athleteId': _resolvedAthleteId ?? widget.athleteId,
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
