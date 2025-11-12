import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import 'manage_plan.dart';

class ManageAthletesScreen extends StatefulWidget {
  final String trainerId;
  const ManageAthletesScreen({Key? key, required this.trainerId}) : super(key: key);

  @override
  _ManageAthletesScreenState createState() => _ManageAthletesScreenState();
}

class _ManageAthletesScreenState extends State<ManageAthletesScreen> {
  final _pb = PocketBaseService();
  List<dynamic> _athletes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _pb.fetchAthletesForTrainer(widget.trainerId);
      setState(() => _athletes = items);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Showing ${items.length} athletes')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateAthleteDialog() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final form = GlobalKey<FormState>();
    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Create athlete'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => (v==null||v.isEmpty)?'Required':null),
              TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), validator: (v) => (v==null||v.isEmpty)?'Required':null),
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display name (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (form.currentState?.validate() ?? false) Navigator.of(ctx).pop(true);
          }, child: const Text('Create')),
        ],
      );
    });

    if (res != true) return;
    try {
      await _pb.createAthlete(emailCtrl.text.trim(), passCtrl.text, displayName: nameCtrl.text.trim(), trainerId: widget.trainerId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Athlete created')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create athlete failed: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Athletes'), actions: [
        IconButton(
          tooltip: 'Debug trainer field',
          icon: const Icon(Icons.bug_report),
          onPressed: () async {
            // Fetch raw athlete records and show trainer field shapes
            try {
              final items = await _pb.fetchAllAthleteRecords();
              if (!mounted) return;
              await showDialog<void>(context: context, builder: (ctx) {
                return AlertDialog(
                  title: const Text('Athlete trainer fields'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (c, i) {
                        final it = items[i] as Map<String,dynamic>;
                        final email = it['email'] ?? '<no-email>';
                        final trainerField = it['trainer'];
                        String trainerStr;
                        try {
                          if (trainerField == null) trainerStr = 'null';
                          else if (trainerField is String) trainerStr = trainerField;
                          else trainerStr = jsonEncode(trainerField);
                        } catch (e) {
                          trainerStr = trainerField.toString();
                        }
                        return ListTile(title: Text(email as String), subtitle: Text(trainerStr));
                      },
                    ),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
                );
              });
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debug fetch failed: ${e.toString()}')));
            }
          },
        )
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: _athletes.length + 1,
          itemBuilder: (ctx, idx) {
            if (idx == 0) {
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(onPressed: _showCreateAthleteDialog, icon: const Icon(Icons.person_add), label: const Text('Create athlete')),
              );
            }
            final a = _athletes[idx-1] as Map<String,dynamic>;
            final name = a['displayName'] ?? a['email'] ?? 'Unknown';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                        IconButton(
                          tooltip: 'Delete athlete',
                          icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.primary),
                          onPressed: () async {
                            // Confirmation dialog
                            final confirmed = await showDialog<bool>(context: context, builder: (ctx) {
                              return AlertDialog(
                                title: const Text('Delete athlete?'),
                                content: Text('Are you sure you want to delete $name? This cannot be undone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                ],
                              );
                            });
                            if (confirmed != true) return;
                            // Perform deletion
                            try {
                              await _pb.deleteUser(a['id'] as String);
                              if (!mounted) return;
                              // remove from local list for immediate UI feedback
                              setState(() {
                                _athletes.removeWhere((e) => (e as Map<String,dynamic>)['id'] == a['id']);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Athlete deleted')));
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: ${e.toString()}')));
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(a['email'] ?? ''),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManagePlanScreen(athleteId: a['id'] as String, athleteName: name, trainerId: widget.trainerId)));
                          },
                          child: const Text('Manage plan'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AthleteDetailScreen extends StatefulWidget {
  final Map<String,dynamic> athlete;
  final String trainerId;
  const AthleteDetailScreen({Key? key, required this.athlete, required this.trainerId}) : super(key: key);

  @override
  _AthleteDetailScreenState createState() => _AthleteDetailScreenState();
}

class _AthleteDetailScreenState extends State<AthleteDetailScreen> {
  final _pb = PocketBaseService();
  List<dynamic> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _pb.fetchPlansForAthlete(widget.athlete['id'] as String);
      setState(() => _plans = items);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createPlan() async {
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    final exercisesCtrl = TextEditingController(text: '[{"id":"e1","name":"Sample","sets":3,"reps":"8"}]');
    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Create plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
            TextField(controller: exercisesCtrl, decoration: const InputDecoration(labelText: 'Exercises (JSON array)')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create'))],
      );
    });
    if (res != true) return;
    try {
      final exercises = jsonDecode(exercisesCtrl.text) as List<dynamic>;
      await _pb.createPlan(widget.athlete['id'] as String, dateCtrl.text.trim(), exercises, createdBy: widget.trainerId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan created')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create plan failed: ${e.toString()}')));
    }
  }

  Future<void> _applyTemplate() async {
    final tplIdCtrl = TextEditingController();
    final startDateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    final weeksCtrl = TextEditingController(text: '10');
    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Apply template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tplIdCtrl, decoration: const InputDecoration(labelText: 'Template id')),
            TextField(controller: startDateCtrl, decoration: const InputDecoration(labelText: 'Start date (YYYY-MM-DD)')),
            TextField(controller: weeksCtrl, decoration: const InputDecoration(labelText: 'Weeks')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply'))],
      );
    });
    if (res != true) return;
    try {
      final startDate = DateTime.parse(startDateCtrl.text.trim());
      final weeks = int.tryParse(weeksCtrl.text.trim()) ?? 10;
      await _pb.applyTemplateToAthlete(tplIdCtrl.text.trim(), widget.athlete['id'] as String, startDate, weeks, createdBy: widget.trainerId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template applied')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apply failed: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.athlete['displayName'] ?? widget.athlete['email'];
    return Scaffold(
      appBar: AppBar(title: Text('Athlete: ${name ?? ''}')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: _plans.length + 2,
          itemBuilder: (ctx, idx) {
            if (idx == 0) return Padding(padding: const EdgeInsets.all(12.0), child: ElevatedButton(onPressed: _createPlan, child: const Text('Create plan')));
            if (idx == 1) return Padding(padding: const EdgeInsets.all(12.0), child: ElevatedButton(onPressed: _applyTemplate, child: const Text('Apply template')));
            final p = _plans[idx-2] as Map<String,dynamic>;
            return ListTile(
              title: Text(p['date'] ?? ''),
              subtitle: Text((p['exercises'] is String) ? p['exercises'] : jsonEncode(p['exercises'])),
              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                try {
                  await _pb.deletePlan(p['id'] as String);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                  await _load();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: ${e.toString()}')));
                }
              }),
            );
          },
        ),
      ),
    );
  }
}
