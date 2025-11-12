import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class ManagePlanScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;
  final String trainerId;
  const ManagePlanScreen({Key? key, required this.athleteId, required this.athleteName, required this.trainerId}) : super(key: key);

  @override
  _ManagePlanScreenState createState() => _ManagePlanScreenState();
}

class _ManagePlanScreenState extends State<ManagePlanScreen> {
  final _pb = PocketBaseService();
  DateTime _selected = DateTime.now();
  Map<String, dynamic>? _plan; // single plan for the selected date
  bool _loading = true;

  Map<String, dynamic> _emptyPlanForDate(String date) => {
        'id': null,
        'date': date,
        'title': 'Custom plan',
        'exercises': <Map<String, dynamic>>[],
      };

  /// Safely parse the exercises field from a plan record and always return a List.
  List<dynamic> _exercisesFromPlan(Map<String, dynamic>? plan) {
    if (plan == null) return <dynamic>[];
    final raw = plan['exercises'];
    if (raw == null) return <dynamic>[];
    if (raw is List) return raw;
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return <dynamic>[];
      try {
        final parsed = jsonDecode(s);
        if (parsed is List) return parsed;
        return <dynamic>[];
      } catch (_) {
        // Malformed JSON -> treat as empty list
        return <dynamic>[];
      }
    }
    // Unknown shape -> return empty
    return <dynamic>[];
  }
  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    setState(() => _loading = true);
    // compute date up-front so we can set a sensible default on error
    final date = _selected.toIso8601String().substring(0,10);
    try {
      final plans = await _pb.fetchPlansForAthlete(widget.athleteId);
      if (!mounted) return;
      final matched = plans.firstWhere((p) => (p['date'] ?? '') == date, orElse: () => null);
      if (matched != null) {
        setState(() => _plan = matched as Map<String, dynamic>?);
      } else {
        setState(() => _plan = {
          'id': null,
          'date': date,
          'title': 'Custom plan',
          'exercises': <Map<String,dynamic>>[],
        });
      }
    } catch (e) {
      // Ensure _plan is non-null so the UI doesn't crash when build() dereferences it.
      if (mounted) {
        setState(() => _plan = {
          'id': null,
          'date': date,
          'title': 'Custom plan',
          'exercises': <Map<String,dynamic>>[],
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePlan() async {
    if (_plan == null) return;
    try {
      final exercises = _plan!['exercises'];
      if (_plan!['id'] == null) {
        await _pb.createPlan(widget.athleteId, _plan!['date'], exercises, createdBy: widget.trainerId);
      } else {
        await _pb.updatePlan(_plan!['id'] as String, {'exercises': exercises, 'date': _plan!['date']});
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan saved')));
      await _loadPlan();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: ${e.toString()}')));
    }
  }

  Future<void> _addExercise() async {
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '8');
    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Add exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Exercise name')),
            TextField(controller: setsCtrl, decoration: const InputDecoration(labelText: 'Sets'), keyboardType: TextInputType.number),
            TextField(controller: repsCtrl, decoration: const InputDecoration(labelText: 'Reps')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add'))],
      );
    });
    if (res != true) return;
    final ex = {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': nameCtrl.text.trim(), 'sets': int.tryParse(setsCtrl.text) ?? 3, 'reps': repsCtrl.text.trim()};
    setState(() {
      if (_plan == null) {
        _plan = _emptyPlanForDate(_selected.toIso8601String().substring(0,10));
      }
      final list = _exercisesFromPlan(_plan);
      list.add(ex);
      _plan!['exercises'] = list;
    });
  }

  Future<void> _editExercise(int index) async {
  if (_plan == null) return; // nothing to edit
  final currentList = _exercisesFromPlan(_plan);
  if (index < 0 || index >= currentList.length) return;
  final current = currentList[index];
    final nameCtrl = TextEditingController(text: current['name'] ?? '');
    final setsCtrl = TextEditingController(text: (current['sets'] ?? '').toString());
    final repsCtrl = TextEditingController(text: (current['reps'] ?? '').toString());
    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Edit exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Exercise name')),
            TextField(controller: setsCtrl, decoration: const InputDecoration(labelText: 'Sets'), keyboardType: TextInputType.number),
            TextField(controller: repsCtrl, decoration: const InputDecoration(labelText: 'Reps')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save'))],
      );
    });
    if (res != true) return;
    setState(() {
      final list = _exercisesFromPlan(_plan);
      list[index] = {'id': list[index]['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), 'name': nameCtrl.text.trim(), 'sets': int.tryParse(setsCtrl.text) ?? 3, 'reps': repsCtrl.text.trim()};
      _plan!['exercises'] = list;
    });
  }

  Future<void> _deleteExercise(int index) async {
    if (_plan == null) return;
    setState(() {
      final list = _exercisesFromPlan(_plan);
      if (index >= 0 && index < list.length) list.removeAt(index);
      _plan!['exercises'] = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Plan: ${widget.athleteName}')),
      body: Column(
        children: [
          ListTile(
            title: Text('Selected date: ${_selected.toLocal().toIso8601String().substring(0,10)}'),
            trailing: Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _selected, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) {
                setState(() => _selected = d);
                await _loadPlan();
              }
            },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Builder(builder: (context) {
                    try {
                      final plan = _plan ?? _emptyPlanForDate(_selected.toIso8601String().substring(0, 10));
                      final exercises = _exercisesFromPlan(plan);
                      if (exercises.isEmpty) return Center(child: Text('No exercises — add one with the + button'));
                      // Use a ReorderableListView so the trainer can drag to reorder exercises.
                      return ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: exercises.length,
                        onReorder: (oldIndex, newIndex) async {
                          // Normalize indexes
                          if (oldIndex < 0 || oldIndex >= exercises.length) return;
                          if (newIndex < 0) newIndex = 0;
                          if (newIndex > exercises.length) newIndex = exercises.length;
                          setState(() {
                            final item = exercises.removeAt(oldIndex);
                            // insert at newIndex; when moving down, newIndex already accounts for removal
                            exercises.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
                            // write back into _plan
                            if (_plan == null) _plan = _emptyPlanForDate(_selected.toIso8601String().substring(0,10));
                            _plan!['exercises'] = exercises;
                          });

                          // Persist order if this plan exists on the server
                          try {
                            if (_plan != null && _plan!['id'] != null) {
                              final planId = _plan!['id'] as String;
                              await _pb.updatePlan(planId, {'exercises': exercises, 'date': _plan!['date']});
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exercise order saved')));
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save order failed: ${e.toString()}')));
                          }
                        },
                        itemBuilder: (ctx, i) {
                          final ex = exercises[i] as Map<String, dynamic>;
                          final key = ValueKey(ex['id'] ?? i);
                          return Container(
                            key: key,
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                            child: Card(
                              child: ListTile(
                                leading: ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Icon(Icons.drag_indicator),
                                  ),
                                ),
                                title: Text(ex['name'] ?? ''),
                                subtitle: Text('Sets: ${ex['sets'] ?? ''} • Reps: ${ex['reps'] ?? ''}'),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _editExercise(i)),
                                  IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteExercise(i)),
                                ]),
                              ),
                            ),
                          );
                        },
                      );
                    } catch (e) {
                      // Defensive: if parsing fails, surface a helpful message and log raw plan
                      try { print('ManagePlan: failed to build exercises: $e'); } catch (_) {}
                      try { print('ManagePlan: raw plan exercises=${_plan?['exercises']}'); } catch (_) {}
                      return Center(child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('Unable to show plan — data appears malformed. You can add a new plan or contact admin.'),
                      ));
                    }
                  }),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addExercise,
            child: const Icon(Icons.add),
            tooltip: 'Add exercise',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'save',
            onPressed: _savePlan,
            child: const Icon(Icons.save),
            tooltip: 'Save plan',
          ),
        ],
      ),
    );
  }
}
