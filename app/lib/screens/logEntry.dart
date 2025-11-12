import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import '../widgets/account_action.dart';

class LogEntryScreen extends StatefulWidget {
  final String athleteId;
  final String planId;
  final String exerciseId;
  final Map<String, dynamic>? exercise; // optional full exercise data passed from DayView

  const LogEntryScreen({Key? key, required this.athleteId, required this.planId, required this.exerciseId, this.exercise}) : super(key: key);

  @override
  _LogEntryScreenState createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  final PocketBaseService _pb = PocketBaseService();
  String _displayName = '';

  // controllers per set
  List<TextEditingController> _weightControllers = [];
  List<bool> _savedFlags = [];

  int _setsCount = 1;
  int _repsPerSet = 0;

  @override
  void initState() {
    super.initState();
    _initFromExercise();
    _loadProfile();
  }

  void _initFromExercise() {
    final ex = widget.exercise;
    if (ex != null) {
      // sets may be numeric or string
      final s = ex['sets'];
      final r = ex['reps'];
      _setsCount = (s is int) ? s : (int.tryParse(s?.toString() ?? '') ?? 1);
      _repsPerSet = (r is int) ? r : (int.tryParse(r?.toString() ?? '') ?? 0);
    }
    if (_setsCount < 1) _setsCount = 1;
    _weightControllers = List.generate(_setsCount, (_) => TextEditingController());
    _savedFlags = List.generate(_setsCount, (_) => false);
  }

  Future<void> _save() async {
    final sets = <Map<String, dynamic>>[];
    for (var i = 0; i < _setsCount; i++) {
      final weight = double.tryParse(_weightControllers[i].text) ?? 0.0;
      sets.add({
        'weight': weight,
        'reps': _repsPerSet,
        'notes': '',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    try {
      await _pb.createLog(widget.athleteId, widget.planId, widget.exerciseId, sets);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save log')));
    }
  }

  Future<void> _saveSet(int index) async {
    if (index < 0 || index >= _setsCount) return;
    final text = _weightControllers[index].text;
    final weight = double.tryParse(text) ?? 0.0;
    if (weight <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid weight before saving')));
      return;
    }

    final set = {
      'weight': weight,
      'reps': _repsPerSet,
      'notes': '',
      'timestamp': DateTime.now().toIso8601String(),
    };
    try {
      await _pb.createLog(widget.athleteId, widget.planId, widget.exerciseId, [set]);
      if (!mounted) return;
      setState(() => _savedFlags[index] = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved set ${index + 1}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save set')));
    }
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
  void dispose() {
    for (final c in _weightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final ex = widget.exercise;
  final exName = (ex != null) ? (ex['name'] ?? widget.exerciseId) : widget.exerciseId;

    return Scaffold(
      appBar: AppBar(title: Text(exName.toString()), actions: [Padding(padding: const EdgeInsets.only(right:8.0), child: AccountAction(displayName: _displayName))]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(child: Text(exName.toString(), style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 12),

            // One compact centered row per set: small weight input + 'x' + reps
            ...List.generate(_setsCount, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 48,
                      child: TextField(
                        controller: _weightControllers[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Weight',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('x', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                      child: Text(_repsPerSet.toString(), style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(width: 12),
                    // per-set save / status
                    IconButton(
                      icon: _savedFlags[i] ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.save),
                      onPressed: () => _saveSet(i),
                      tooltip: _savedFlags[i] ? 'Saved' : 'Save set',
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 18),
            // video placeholder
            Text('Video', style: Theme.of(context).textTheme.bodyMedium),
            Container(
              margin: const EdgeInsets.only(top: 8.0),
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8.0)),
              child: const Center(child: Text('Video placeholder')),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _save, child: const Text('Save'))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
