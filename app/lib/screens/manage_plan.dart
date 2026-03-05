import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Plan management screen — create, edit, and organize workout plans by date.
class ManagePlanScreen extends StatefulWidget {
  final String? initialDate;
  const ManagePlanScreen({Key? key, this.initialDate}) : super(key: key);

  @override
  _ManagePlanScreenState createState() => _ManagePlanScreenState();
}

class _ManagePlanScreenState extends State<ManagePlanScreen> {
  final _db = DatabaseService();
  DateTime _selected = DateTime.now();
  Map<String, dynamic>? _plan;
  bool _loading = true;

  Map<String, dynamic> _emptyPlanForDate(String date) => {
        'id': null,
        'date': date,
        'exercises': <Map<String, dynamic>>[],
      };

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
      } catch (_) {}
    }
    return <dynamic>[];
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selected = DateTime.tryParse(widget.initialDate!) ?? DateTime.now();
    }
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    setState(() => _loading = true);
    final date = _selected.toIso8601String().substring(0, 10);
    try {
      final plans = await _db.fetchPlansForDate(date);
      if (!mounted) return;
      if (plans.isNotEmpty) {
        setState(() => _plan = plans.first);
      } else {
        setState(() => _plan = _emptyPlanForDate(date));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _plan = _emptyPlanForDate(date));
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
        final created = await _db.createPlan(_plan!['date'], exercises is List ? exercises : []);
        setState(() => _plan = created);
      } else {
        await _db.updatePlan(_plan!['id'] as String, {'exercises': exercises, 'date': _plan!['date']});
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
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add exercise'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Exercise name')),
          TextField(controller: setsCtrl, decoration: const InputDecoration(labelText: 'Sets'), keyboardType: TextInputType.number),
          TextField(controller: repsCtrl, decoration: const InputDecoration(labelText: 'Reps')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (res != true) return;
    final ex = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': nameCtrl.text.trim(),
      'sets': int.tryParse(setsCtrl.text) ?? 3,
      'reps': repsCtrl.text.trim(),
    };
    setState(() {
      _plan ??= _emptyPlanForDate(_selected.toIso8601String().substring(0, 10));
      final list = _exercisesFromPlan(_plan);
      list.add(ex);
      _plan!['exercises'] = list;
    });
  }

  Future<void> _editExercise(int index) async {
    if (_plan == null) return;
    final currentList = _exercisesFromPlan(_plan);
    if (index < 0 || index >= currentList.length) return;
    final current = currentList[index];
    final nameCtrl = TextEditingController(text: current['name'] ?? '');
    final setsCtrl = TextEditingController(text: (current['sets'] ?? '').toString());
    final repsCtrl = TextEditingController(text: (current['reps'] ?? '').toString());
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit exercise'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Exercise name')),
          TextField(controller: setsCtrl, decoration: const InputDecoration(labelText: 'Sets'), keyboardType: TextInputType.number),
          TextField(controller: repsCtrl, decoration: const InputDecoration(labelText: 'Reps')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (res != true) return;
    setState(() {
      final list = _exercisesFromPlan(_plan);
      list[index] = {
        'id': list[index]['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'name': nameCtrl.text.trim(),
        'sets': int.tryParse(setsCtrl.text) ?? 3,
        'reps': repsCtrl.text.trim(),
      };
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
      appBar: AppBar(title: const Text('Manage Plans')),
      body: Column(
        children: [
          ListTile(
            title: Text('Selected date: ${_selected.toLocal().toIso8601String().substring(0, 10)}'),
            trailing: const Icon(Icons.calendar_today),
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
                    final plan = _plan ?? _emptyPlanForDate(_selected.toIso8601String().substring(0, 10));
                    final exercises = _exercisesFromPlan(plan);
                    if (exercises.isEmpty) return const Center(child: Text('No exercises — tap + to add one'));
                    return ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: exercises.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (oldIndex < 0 || oldIndex >= exercises.length) return;
                        if (newIndex > exercises.length) newIndex = exercises.length;
                        setState(() {
                          final item = exercises.removeAt(oldIndex);
                          exercises.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
                          _plan ??= _emptyPlanForDate(_selected.toIso8601String().substring(0, 10));
                          _plan!['exercises'] = exercises;
                        });
                        try {
                          if (_plan != null && _plan!['id'] != null) {
                            await _db.updatePlan(_plan!['id'] as String, {'exercises': exercises, 'date': _plan!['date']});
                          }
                        } catch (_) {}
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
                                child: const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.drag_indicator)),
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
                  }),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(heroTag: 'add', onPressed: _addExercise, tooltip: 'Add exercise', child: const Icon(Icons.add)),
          const SizedBox(height: 8),
          FloatingActionButton(heroTag: 'save', onPressed: _savePlan, tooltip: 'Save plan', child: const Icon(Icons.save)),
        ],
      ),
    );
  }
}

