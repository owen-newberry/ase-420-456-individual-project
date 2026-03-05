import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Create or edit a workout template with day-of-week exercise assignments.
class ManageTemplateScreen extends StatefulWidget {
  final String? templateId;
  const ManageTemplateScreen({Key? key, this.templateId}) : super(key: key);

  @override
  _ManageTemplateScreenState createState() => _ManageTemplateScreenState();
}

class _ManageTemplateScreenState extends State<ManageTemplateScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  String _name = '';
  String? _templateId;
  List<Map<String, dynamic>> _exercises = [];

  static const List<String> _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _templateId = widget.templateId;
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    setState(() => _loading = true);
    if (_templateId == null) {
      setState(() {
        _name = 'New Template';
        _exercises = [];
        _loading = false;
      });
      return;
    }
    try {
      final tpl = await _db.getTemplateById(_templateId!);
      setState(() {
        _name = tpl['name'] ?? '';
        final raw = tpl['exercises'];
        if (raw == null) {
          _exercises = [];
        } else if (raw is String) {
          try {
            final parsed = jsonDecode(raw);
            if (parsed is List) _exercises = List<Map<String, dynamic>>.from(parsed.map((e) => Map<String, dynamic>.from(e)));
            else _exercises = [];
          } catch (_) { _exercises = []; }
        } else if (raw is List) {
          _exercises = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e)));
        } else {
          _exercises = [];
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load template failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _exercisesForDay(int day) {
    return _exercises.where((e) => (e['day'] ?? 0) == day).toList();
  }

  Future<void> _addExerciseForDay(int day) async {
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
    setState(() {
      _exercises.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': nameCtrl.text.trim(),
        'sets': int.tryParse(setsCtrl.text) ?? 3,
        'reps': repsCtrl.text.trim(),
        'day': day,
      });
    });
  }

  Future<void> _editExercise(Map<String, dynamic> ex) async {
    final nameCtrl = TextEditingController(text: ex['name'] ?? '');
    final setsCtrl = TextEditingController(text: (ex['sets'] ?? '').toString());
    final repsCtrl = TextEditingController(text: (ex['reps'] ?? '').toString());
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
      final idx = _exercises.indexWhere((e) => e['id'] == ex['id']);
      if (idx >= 0) {
        _exercises[idx] = {
          ..._exercises[idx],
          'name': nameCtrl.text.trim(),
          'sets': int.tryParse(setsCtrl.text) ?? 3,
          'reps': repsCtrl.text.trim(),
        };
      }
    });
  }

  Future<void> _deleteExercise(String id) async {
    setState(() {
      _exercises.removeWhere((e) => e['id'] == id);
    });
  }

  Future<void> _saveTemplate() async {
    setState(() => _loading = true);
    try {
      if (_templateId == null) {
        final created = await _db.createTemplate(_name, _exercises);
        _templateId = created['id'] as String?;
      } else {
        await _db.updateTemplate(_templateId!, {'name': _name, 'exercises': _exercises});
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_templateId == null ? 'New Template' : 'Edit Template')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Template name'),
                    controller: TextEditingController(text: _name),
                    onChanged: (v) => _name = v,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 7,
                      itemBuilder: (ctx, day) {
                        final items = _exercisesForDay(day);
                        return Card(
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            title: Text(_dayNames[day]),
                            trailing: IconButton(icon: const Icon(Icons.add), onPressed: () => _addExerciseForDay(day)),
                            children: items.isEmpty
                                ? [const ListTile(title: Text('No exercises'))]
                                : items.map((ex) {
                                    return ListTile(
                                      title: Text(ex['name'] ?? ''),
                                      subtitle: Text('Sets: ${ex['sets'] ?? ''} • Reps: ${ex['reps'] ?? ''}'),
                                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _editExercise(ex)),
                                        IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteExercise(ex['id'] as String)),
                                      ]),
                                    );
                                  }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'saveTpl',
            onPressed: _saveTemplate,
            label: const Text('Save'),
            icon: const Icon(Icons.save),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'applyTpl',
            onPressed: () async {
              if (_templateId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please save the template first')));
                return;
              }
              final weeksCtrl = TextEditingController(text: '1');
              final res = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Apply template'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Create plans from this template starting today.'),
                    const SizedBox(height: 12),
                    TextField(controller: weeksCtrl, decoration: const InputDecoration(labelText: 'Weeks'), keyboardType: TextInputType.number),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply')),
                  ],
                ),
              );
              if (res == true) {
                final weeks = int.tryParse(weeksCtrl.text) ?? 1;
                try {
                  await _db.applyTemplate(_templateId!, DateTime.now(), weeks);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template applied')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apply failed: ${e.toString()}')));
                }
              }
            },
            label: const Text('Apply'),
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
