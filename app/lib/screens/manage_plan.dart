import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
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
  // PocketBase instance for this project enforces a 5 MB limit on the `file` field.
  // Keep this in-sync with the server schema. Value in bytes.
  static const int _maxFileSizeBytes = 5242880; // 5 * 1024 * 1024
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
                                  IconButton(icon: const Icon(Icons.video_file), onPressed: () => _uploadVideoForExercise(i)),
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
                      // debug logging removed
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

  Future<void> _uploadVideoForExercise(int index) async {
    if (_plan == null) return;
    final exercises = _exercisesFromPlan(_plan);
    if (index < 0 || index >= exercises.length) return;
    final ex = exercises[index] as Map<String,dynamic>;
    final titleCtrl = TextEditingController(text: '${ex['name'] ?? 'Exercise'} demo');
    final descCtrl = TextEditingController(text: ex['description'] ?? '');
    // Ask for title/description before opening file selector
    final metaOk = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Video metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 8),
            // Show the max file size so trainers know upload limits before picking a file
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Max file size: ${(_maxFileSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue')),
        ],
      );
    });
    if (metaOk != true) return;
    // Pick the file first (some platforms return bytes instead of a filesystem path)
    // Use file_selector which has better platform support and updated embedding.
    XFile? xfile;
    try {
      final typeGroup = XTypeGroup(label: 'videos', extensions: ['mp4', 'mov', 'mkv', 'webm', 'avi']);
      xfile = await openFile(acceptedTypeGroups: [typeGroup]);
    } on MissingPluginException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File selector plugin not registered. Stop the app and run a full rebuild (flutter run) to enable native plugins.'),
        ));
      }
      return;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File pick failed: ${e.toString()}')));
      return;
    }
    if (xfile == null) return;
  final title = titleCtrl.text.trim().isEmpty ? (ex['name'] ?? 'Video') : titleCtrl.text.trim();
  final description = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
    try {
      Map<String, dynamic> vid;
      // Always read bytes from the picked file and upload them. Some Android
      // pickers return content URIs or transient paths that MultipartFile.fromPath
      // cannot handle; uploading from bytes is more reliable across platforms.
  final bytes = await xfile.readAsBytes();
  // Validate size against the server's configured max before attempting upload
      if (bytes.length > _maxFileSizeBytes) {
        final maxMb = (_maxFileSizeBytes / 1024 / 1024).toStringAsFixed(1);
        final actualMb = (bytes.length / 1024 / 1024).toStringAsFixed(2);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected file is too large ($actualMb MB). Max is $maxMb MB. Please choose a smaller file or adjust server settings.')));
        }
        return;
      }

      // If the exercise already has a video record, attempt to update its file
      // so we keep exactly one video per exercise. If the server doesn't allow
      // updating the file on an existing record we fall back to creating a new
      // record and replacing the reference.
      if (ex['video'] != null && ex['video'] is Map && (ex['video']['id'] ?? ex['video']['_id']) != null) {
        final existingId = (ex['video']['id'] ?? ex['video']['_id']) as String;
        try {
          final updated = await _pb.updateVideoFile(existingId, bytes: bytes, filename: xfile.name);
          // update metadata if title/description changed
          try {
            await _pb.updateVideoMetadata(existingId, title: title, description: description);
          } catch (_) {}
          ex['video'] = updated;
          _plan!['exercises'] = exercises;
          await _savePlan();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video updated and attached')));
        } catch (e) {
          // Update failed (server may not support per-record file upload). Fall
          // back to creating a new video record and replace the reference.
          try {
            final created = await _pb.uploadVideo(title, description: description, bytes: bytes, filename: xfile.name);
            ex['video'] = created;
            _plan!['exercises'] = exercises;
            await _savePlan();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Previous video replaced with a new upload')));
          } catch (e2) {
            rethrow;
          }
        }
      } else {
        // No existing video: create a new one normally
        vid = await _pb.uploadVideo(title, description: description, bytes: bytes, filename: xfile.name);
        // attach returned video info to the exercise so athlete UI can show it
        ex['video'] = vid;
        // write back and save the plan
        _plan!['exercises'] = exercises;
        await _savePlan();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video uploaded and attached')));
      }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.toString()}')));
      }
    }
  }

