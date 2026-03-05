import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'package:forge_workout/utils/route_observer.dart';

/// Log entry screen — enter weights per set for a specific exercise.
class LogEntryScreen extends StatefulWidget {
  final String planId;
  final String exerciseId;
  final Map<String, dynamic>? exercise;

  const LogEntryScreen({
    Key? key,
    required this.planId,
    required this.exerciseId,
    this.exercise,
  }) : super(key: key);

  @override
  _LogEntryScreenState createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> with RouteAware {
  final DatabaseService _db = DatabaseService();
  final bool _mapSavedWeightsToLast = true;

  List<TextEditingController> _weightControllers = [];
  int _setsCount = 1;
  int _repsPerSet = 0;

  @override
  void initState() {
    super.initState();
    _initFromExercise();
    _populateSavedWeights();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final route = ModalRoute.of(context);
      if (route != null) {
        routeObserver.subscribe(this, route as PageRoute<dynamic>);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    try { routeObserver.unsubscribe(this); } catch (_) {}
    for (final c in _weightControllers) { c.dispose(); }
    super.dispose();
  }

  @override
  void didPopNext() {
    _populateSavedWeights();
  }

  void _initFromExercise() {
    final ex = widget.exercise;
    if (ex != null) {
      final s = ex['sets'];
      final r = ex['reps'];
      _setsCount = (s is int) ? s : (int.tryParse(s?.toString() ?? '') ?? 1);
      _repsPerSet = (r is int) ? r : (int.tryParse(r?.toString() ?? '') ?? 0);
    }
    if (_setsCount < 1) _setsCount = 1;
    _weightControllers = List.generate(_setsCount, (_) => TextEditingController());
  }

  void _ensureControllersCount() {
    if (_weightControllers.length == _setsCount) return;
    final newList = <TextEditingController>[];
    final minLen = _weightControllers.length < _setsCount ? _weightControllers.length : _setsCount;
    for (var i = 0; i < minLen; i++) newList.add(_weightControllers[i]);
    for (var i = minLen; i < _setsCount; i++) newList.add(TextEditingController());
    if (_weightControllers.length > _setsCount) {
      for (var i = _setsCount; i < _weightControllers.length; i++) {
        try { _weightControllers[i].dispose(); } catch (_) {}
      }
    }
    _weightControllers = newList;
  }

  Future<void> _populateSavedWeights() async {
    try {
      _ensureControllersCount();

      // Try plan-based weights first
      Map<String, dynamic>? plan;
      try { plan = await _db.getPlanById(widget.planId); } catch (_) {}
      var exercisesRaw = plan?['exercises'];
      List<dynamic> exercises = [];
      if (exercisesRaw is String) {
        try { final p = jsonDecode(exercisesRaw); if (p is List) exercises = p; } catch (_) {}
      } else if (exercisesRaw is List) {
        exercises = exercisesRaw;
      }

      if (exercises.isNotEmpty) {
        Map<String, dynamic>? matched;
        for (final ex in exercises) {
          if (ex is Map) {
            final idCandidates = [ex['id'], ex['exerciseId'], ex['name']];
            for (final c in idCandidates) {
              if (c != null && c.toString() == widget.exerciseId) {
                matched = Map<String, dynamic>.from(ex);
                break;
              }
            }
            if (matched != null) break;
          }
        }

        if (matched != null) {
          final setsRaw = matched['sets'];
          List<Map<String, dynamic>> planSets = [];
          if (setsRaw != null && !(setsRaw is num) && !(setsRaw is String && int.tryParse(setsRaw) != null)) {
            planSets = _db.normalizeSetsField(setsRaw);
          }
          if (planSets.isNotEmpty) {
            _setsCount = planSets.length;
            _ensureControllersCount();
            for (var i = 0; i < _setsCount && i < planSets.length; i++) {
              final s = planSets[i];
              double w = 0.0;
              if (s['weight'] != null) {
                w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
              }
              _weightControllers[i].text = w == 0.0 ? '' : w.toString();
            }
            setState(() {});
            return;
          }
        }
      }

      // Check local cache
      try {
        final sp = await SharedPreferences.getInstance();
        final key = 'last_log_${widget.exerciseId}';
        final cached = sp.getString(key);
        if (cached != null && cached.isNotEmpty) {
          final parsed = jsonDecode(cached);
          final cachedSets = _db.normalizeSetsField(parsed);
          if (cachedSets.isNotEmpty) {
            final savedLen = cachedSets.length;
            if (savedLen != _setsCount) {
              _setsCount = savedLen;
              _ensureControllersCount();
            }
            for (var i = 0; i < _setsCount && i < savedLen; i++) {
              final s = cachedSets[i];
              double w = 0.0;
              if (s['weight'] != null) {
                w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
              }
              _weightControllers[i].text = w == 0.0 ? '' : w.toString();
            }
            setState(() {});
            return;
          }
        }
      } catch (_) {}

      // Fall back to most recent log from DB
      List<Map<String, dynamic>> logs = [];
      try {
        logs = await _db.fetchLogsForExercise(widget.exerciseId, planId: widget.planId, limit: 1);
      } catch (_) {}
      if (logs.isEmpty) return;
      final latest = logs.first;
      dynamic setsField = latest['sets'];
      final savedSets = _db.normalizeSetsField(setsField);
      if (savedSets.isEmpty) return;

      final savedLen = savedSets.length;
      if (_mapSavedWeightsToLast) {
        final start = (_setsCount - savedLen) > 0 ? (_setsCount - savedLen) : 0;
        for (var i = 0; i < savedLen && (start + i) < _setsCount; i++) {
          final s = savedSets[i];
          double w = 0.0;
          if (s['weight'] != null) {
            w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
          }
          _weightControllers[start + i].text = w == 0.0 ? '' : w.toString();
        }
      } else {
        for (var i = 0; i < _setsCount && i < savedLen; i++) {
          final s = savedSets[i];
          double w = 0.0;
          if (s['weight'] != null) {
            w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
          }
          _weightControllers[i].text = w == 0.0 ? '' : w.toString();
        }
      }
      setState(() {});
    } catch (_) {}
  }

  Future<void> _save() async {
    final sets = <Map<String, dynamic>>[];
    for (var i = 0; i < _setsCount; i++) {
      final raw = _weightControllers[i].text.trim();
      if (raw.isEmpty) continue;
      final normalized = raw.replaceAll(',', '.');
      final weight = double.tryParse(normalized);
      if (weight == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid weight at set ${i + 1}: "$raw"')));
        return;
      }
      sets.add({
        'weight': weight,
        'reps': _repsPerSet,
        'notes': '',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    if (sets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one weight before saving')));
      return;
    }
    try {
      await _db.createLog(widget.planId, widget.exerciseId, sets);
      // Cache last log
      try {
        final sp = await SharedPreferences.getInstance();
        final key = 'last_log_${widget.exerciseId}';
        await sp.setString(key, jsonEncode(sets));
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log saved')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save log')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final exName = (ex != null) ? (ex['name'] ?? widget.exerciseId) : widget.exerciseId;

    return Scaffold(
      appBar: AppBar(title: Text(exName.toString())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(child: Text(exName.toString(), style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 12),
            ...List.generate(_setsCount, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Set ${i + 1}', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(width: 12),
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
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_repsPerSet.toString(), style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
              );
            }),
            const Spacer(),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _save, child: const Text('Save'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
