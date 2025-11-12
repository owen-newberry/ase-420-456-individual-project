import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class ManageTemplateScreen extends StatefulWidget {
  final String? templateId;
  final String trainerId;
  const ManageTemplateScreen({Key? key, this.templateId, required this.trainerId}) : super(key: key);

  @override
  _ManageTemplateScreenState createState() => _ManageTemplateScreenState();
}

class _ManageTemplateScreenState extends State<ManageTemplateScreen> {
  final _pb = PocketBaseService();
  bool _loading = true;
  String _name = '';
  String? _templateId;
  // exercises stored as list of maps; each item includes a `day` int 0..6 (Sunday..Saturday)
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
      final tpl = await _pb.getTemplateById(_templateId!);
      setState(() {
        _name = tpl['name'] ?? '';
        final raw = tpl['exercises'];
        if (raw == null) _exercises = [];
        else if (raw is String) {
          try {
            final parsed = jsonDecode(raw);
            if (parsed is List) _exercises = List<Map<String,dynamic>>.from(parsed.map((e) => Map<String,dynamic>.from(e)));
            else _exercises = [];
          } catch (_) { _exercises = []; }
        } else if (raw is List) {
          _exercises = List<Map<String,dynamic>>.from(raw.map((e) => Map<String,dynamic>.from(e)));
        } else {
          _exercises = [];
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load template failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String,dynamic>> _exercisesForDay(int day) {
    return _exercises.where((e) => (e['day'] ?? 0) == day).toList();
  }

  Future<void> _addExerciseForDay(int day) async {
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
    final ex = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': nameCtrl.text.trim(),
      'sets': int.tryParse(setsCtrl.text) ?? 3,
      'reps': repsCtrl.text.trim(),
      'day': day,
    };
    setState(() {
      _exercises.add(ex);
    });
  }

  Future<void> _editExercise(Map<String,dynamic> ex) async {
    final nameCtrl = TextEditingController(text: ex['name'] ?? '');
    final setsCtrl = TextEditingController(text: (ex['sets'] ?? '').toString());
    final repsCtrl = TextEditingController(text: (ex['reps'] ?? '').toString());
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
        final created = await _pb.createTemplate(_name, _exercises, createdBy: widget.trainerId);
        _templateId = created['id'] as String?;
      } else {
        await _pb.updateTemplate(_templateId!, {'name': _name, 'exercises': _exercises});
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyTemplate(int weeks, String athleteId) async {
    if (_templateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please save the template before applying')));
      return;
    }
    try {
      // applyTemplateToAthlete will fetch the template and create plans
      await _pb.applyTemplateToAthlete(_templateId!, athleteId, DateTime.now(), weeks, createdBy: widget.trainerId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template applied')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apply failed: ${e.toString()}')));
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
                                  ? [ListTile(title: Text('No exercises'))]
                                  : items.map((ex) {
                                      return ListTile(
                                        title: Text(ex['name'] ?? ''),
                                        subtitle: Text('Sets: ${ex['sets'] ?? ''} • Reps: ${ex['reps'] ?? ''}'),
                                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                          // Allow attaching a demo/video to exercises while editing a template
                                          IconButton(icon: const Icon(Icons.video_file), onPressed: () => _uploadVideoForExercise(ex)),
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
          // Keep apply button small; requires athlete id to apply - we'll prompt for one
          FloatingActionButton.extended(
            heroTag: 'applyTpl',
            onPressed: () async {
              // Show a dropdown of athletes (for this trainer) instead of asking for raw id
              final weeksCtrl = TextEditingController(text: '1');
              String? selectedAthleteId;
              List<dynamic> athletes = [];
              try {
                athletes = await _pb.fetchAthletesForTrainer(widget.trainerId);
              } catch (_) {
                athletes = [];
              }
              final res = await showDialog<bool>(context: context, builder: (ctx) {
                return StatefulBuilder(builder: (ctx2, setState2) {
                  final items = athletes.map((a) {
                    final map = a as Map<String,dynamic>;
                    final label = (map['displayName'] ?? map['email'] ?? map['id']).toString();
                    return DropdownMenuItem(value: map['id'] as String?, child: Text(label));
                  }).toList();
                  return AlertDialog(
                    title: const Text('Apply template to athlete'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (items.isEmpty) const Text('No athletes found for this trainer'),
                        if (items.isNotEmpty)
                          DropdownButton<String?>(
                            value: selectedAthleteId,
                            items: items,
                            hint: const Text('Select athlete'),
                            onChanged: (v) => setState2(() => selectedAthleteId = v),
                          ),
                        TextField(controller: weeksCtrl, decoration: const InputDecoration(labelText: 'Weeks'), keyboardType: TextInputType.number),
                      ],
                    ),
                    actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply'))],
                  );
                });
              });
              if (res == true && selectedAthleteId != null && selectedAthleteId!.isNotEmpty) {
                final weeks = int.tryParse(weeksCtrl.text) ?? 1;
                await _applyTemplate(weeks, selectedAthleteId!);
              }
            },
            label: const Text('Apply'),
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
    );
  }

  /// Allow uploading a demo video and attach it to a template exercise.
  Future<void> _uploadVideoForExercise(Map<String,dynamic> ex) async {
    // Reuse the PocketBaseService upload flow: ask for metadata then pick file
    final titleCtrl = TextEditingController(text: '${ex['name'] ?? 'Exercise'} demo');
    final descCtrl = TextEditingController(text: ex['description'] ?? '');
    final metaOk = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Video metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue'))],
      );
    });
    if (metaOk != true) return;
    // pick file
    try {
      final typeGroup = XTypeGroup(label: 'videos', extensions: ['mp4', 'mov', 'mkv', 'webm', 'avi']);
      final xfile = await openFile(acceptedTypeGroups: [typeGroup]);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final title = titleCtrl.text.trim().isEmpty ? (ex['name'] ?? 'Video') : titleCtrl.text.trim();
      final description = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
      final vid = await _pb.uploadVideo(title, description: description, bytes: bytes, filename: xfile.name);
      // attach video data into the exercise map so template carries the reference
      setState(() {
        final idx = _exercises.indexWhere((e) => e['id'] == ex['id']);
        if (idx >= 0) {
          _exercises[idx] = { ..._exercises[idx], 'video': vid };
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video uploaded and attached to exercise')));
    } on MissingPluginException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File selector plugin not registered. Rebuild the app.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.toString()}')));
    }
  }
}
