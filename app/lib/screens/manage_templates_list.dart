import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import 'manage_template.dart';

class ManageTemplatesListScreen extends StatefulWidget {
  final String trainerId;
  const ManageTemplatesListScreen({Key? key, required this.trainerId}) : super(key: key);

  @override
  _ManageTemplatesListScreenState createState() => _ManageTemplatesListScreenState();
}

class _ManageTemplatesListScreenState extends State<ManageTemplatesListScreen> {
  final _pb = PocketBaseService();
  bool _loading = true;
  List<dynamic> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tpls = await _pb.fetchTemplatesForTrainer(widget.trainerId);
      setState(() => _templates = tpls);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load templates failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTemplate(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Delete template?'),
        content: const Text('This will permanently delete the template.'),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete'))],
      );
    });
    if (ok != true) return;
    try {
      await _pb.deleteTemplate(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template deleted')));
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: ${e.toString()}')));
    }
  }

  Future<void> _applyTemplateFlow(String templateId) async {
    // Fetch athletes for trainer and present a dropdown to choose
    setState(() => _loading = true);
    try {
      final athletes = await _pb.fetchAthletesForTrainer(widget.trainerId);
      if (athletes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No athletes found for this trainer')));
        return;
      }
      String? selectedId = athletes.first['id'] as String?;
      final weeksCtrl = TextEditingController(text: '1');
      final res = await showDialog<bool>(context: context, builder: (ctx) {
        return AlertDialog(
          title: const Text('Apply template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                items: athletes.map<DropdownMenuItem<String>>((a) {
                  final name = (a['displayName'] ?? a['email'] ?? 'Unknown') as String;
                  return DropdownMenuItem(value: a['id'] as String?, child: Text(name));
                }).toList(),
                onChanged: (v) => selectedId = v,
                decoration: const InputDecoration(labelText: 'Athlete'),
              ),
              TextField(controller: weeksCtrl, decoration: const InputDecoration(labelText: 'Weeks'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply')),
          ],
        );
      });
      if (res != true) return;
      final weeks = int.tryParse(weeksCtrl.text) ?? 1;
      if (selectedId == null || selectedId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an athlete')));
        return;
      }
      await _pb.applyTemplateToAthlete(templateId, selectedId!, DateTime.now(), weeks, createdBy: widget.trainerId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template applied successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apply failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Templates')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _templates.isEmpty
                  ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No templates yet')))])
                  : ListView.builder(
                      itemCount: _templates.length,
                      itemBuilder: (ctx, i) {
                        final tpl = _templates[i] as Map<String, dynamic>;
                        final name = tpl['name'] ?? 'Untitled';
                        final id = tpl['id'] as String?;
                        final parsedExercises = <dynamic>[];
                        try {
                          final raw = tpl['exercises'];
                          if (raw is String && raw.isNotEmpty) parsedExercises.addAll(jsonDecode(raw) as List<dynamic>);
                          else if (raw is List) parsedExercises.addAll(raw);
                        } catch (_) {}
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text('${parsedExercises.length} exercises'),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(icon: const Icon(Icons.play_arrow), tooltip: 'Apply', onPressed: id == null ? null : () => _applyTemplateFlow(id)),
                                IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: id == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManageTemplateScreen(templateId: id, trainerId: widget.trainerId))).then((_) => _load())),
                                IconButton(icon: const Icon(Icons.delete), tooltip: 'Delete', onPressed: id == null ? null : () => _deleteTemplate(id)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManageTemplateScreen(trainerId: widget.trainerId))).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
    );
  }
}
