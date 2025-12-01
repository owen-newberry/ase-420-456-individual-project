// dart:convert removed (no longer needed)
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pocketbase_service.dart';
import '../widgets/account_action.dart';
import 'package:app/utils/route_observer.dart';

class LogEntryScreen extends StatefulWidget {
  final String athleteId;
  final String planId;
  final String exerciseId;
  final Map<String, dynamic>? exercise; // optional full exercise data passed from DayView

  const LogEntryScreen({Key? key, required this.athleteId, required this.planId, required this.exerciseId, this.exercise}) : super(key: key);

  @override
  _LogEntryScreenState createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> with RouteAware {
  final PocketBaseService _pb = PocketBaseService();
  String _displayName = '';
  // When true, map historic saved weights to the last N sets when the
  // saved log has fewer entries than the current plan's sets count. If
  // false, saved weights will map to the first N sets.
  final bool _mapSavedWeightsToLast = true;

  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoFuture;

  // controllers per set
  List<TextEditingController> _weightControllers = [];

  int _setsCount = 1;
  int _repsPerSet = 0;

  @override
  void initState() {
    super.initState();
    _initFromExercise();
    _loadProfile();
    _initVideoIfNeeded();
    _populateSavedWeights();
    debugPrint('LogEntry: initState completed for exerciseId=${widget.exerciseId} setsCount=$_setsCount');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // subscribe to route changes so we can refresh when returning to this screen
    try {
      final route = ModalRoute.of(context);
      if (route != null) {
        // subscribe using the shared routeObserver util
        routeObserver.subscribe(this, route as PageRoute<dynamic>);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    for (final c in _weightControllers) {
      c.dispose();
    }
    try { _videoController?.dispose(); } catch (_) {}
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when a covered route has been popped and this route shows again.
    // Refresh saved weights so UI reflects the latest DB state.
    _populateSavedWeights();
  }

  Future<void> _populateSavedWeights() async {
    debugPrint('LogEntry: _populateSavedWeights() called for exerciseId=${widget.exerciseId}');
    // Prefer parsing planned sets from the plan record every time the page
    // loads. This allows the app to show the intended weights/sets defined
    // in the plan itself. If the plan doesn't include weights, we still
    // leave boxes empty so athletes can enter values.
    try {
      // Ensure controllers match current sets count before populating
      _ensureControllersCount();

      Map<String, dynamic>? plan;
      try {
        plan = await _pb.getPlanById(widget.planId);
      } catch (e) {
        debugPrint('LogEntry: getPlanById failed: $e');
        plan = null;
      }
      var exercisesRaw = plan?['exercises'];
      List<dynamic> exercises = [];
      if (exercisesRaw is String) {
        try {
          final p = jsonDecode(exercisesRaw);
          if (p is List) exercises = p;
        } catch (_) {
          exercises = [];
        }
      } else if (exercisesRaw is List) {
        exercises = exercisesRaw;
      }

      if (exercises.isNotEmpty) {
        Map<String, dynamic>? matched;
        for (final ex in exercises) {
          try {
            if (ex is Map) {
              final idCandidates = [ex['id'], ex['exerciseId'], ex['name']];
              for (final c in idCandidates) {
                if (c != null && c.toString() == widget.exerciseId) {
                  matched = Map<String, dynamic>.from(ex);
                  break;
                }
              }
              if (matched != null) break;
            } else if (ex is String) {
              if (ex == widget.exerciseId) {
                // found a simple string entry - no weights available
                matched = {'id': ex};
                break;
              }
            }
          } catch (_) {}
        }

        if (matched != null) {
          // Attempt to extract a `sets` definition from the matched exercise.
          // The plan exercise may contain a `sets` field which is either an
          // integer (count) or a list of template sets with weight/reps.
          final setsRaw = matched['sets'];
          List<Map<String, dynamic>> planSets = [];
          if (setsRaw == null) {
            // nothing to prefill
            planSets = [];
          } else if (setsRaw is num || (setsRaw is String && int.tryParse(setsRaw) != null)) {
            // numeric sets count; nothing to prefill weights from
            planSets = [];
          } else {
            // delegate parsing to normalizeSetsField to coerce weights
            planSets = _pb.normalizeSetsField(setsRaw);
          }


          if (planSets.isNotEmpty) {
            // If the plan spelled out template sets, adjust controllers
            if (planSets.length > 0) {
              _setsCount = planSets.length;
              _ensureControllersCount();
            }
                debugPrint('LogEntry: planSets.length=${planSets.length}, _setsCount=$_setsCount');
            for (var i = 0; i < _setsCount && i < planSets.length; i++) {
              try {
                final s = planSets[i];
                double w = 0.0;
                if (s['weight'] != null) {
                  w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
                }
                    _weightControllers[i].text = w == 0.0 ? '' : w.toString();
                    debugPrint('LogEntry: setting controller[$i] from plan weight=$w');
              } catch (_) {}
            }
            setState(() {});
            return;
          }
        }
      }

      // If plan didn't provide template weights, fall back to most recent saved log
      // First check for a short-lived local cache written immediately after
      // a successful save. This avoids being blocked by occasional server
      // list endpoint failures and ensures the UI pre-fills immediately
      // after saving on the same device/emulator.
      try {
        final sp = await SharedPreferences.getInstance();
        final key = 'last_log_${widget.athleteId}_${widget.exerciseId}';
        try {
          // Diagnostic: list keys so we can verify whether the expected
          // cache entry exists on the device/emulator.
          final allKeys = sp.getKeys();
          debugPrint('LogEntry: SharedPreferences keys=${allKeys.toList()}');
        } catch (_) {}
        debugPrint('LogEntry: cache read attempting key=$key');
        final cached = sp.getString(key);
        debugPrint('LogEntry: cache raw=${cached ?? '<null>'}');
        if (cached != null && cached.isNotEmpty) {
          try {
            final parsed = jsonDecode(cached);
            final cachedSets = _pb.normalizeSetsField(parsed);
            debugPrint('LogEntry: using cached savedSets count=${cachedSets.length}');
            if (cachedSets.isNotEmpty) {
              final savedLen = cachedSets.length;
              if (savedLen > 0) {
                // If cached sets count differs from current controllers, adjust
                if (savedLen != _setsCount) {
                  _setsCount = savedLen;
                  _ensureControllersCount();
                }
                for (var i = 0; i < _setsCount && i < savedLen; i++) {
                  try {
                    final s = cachedSets[i];
                    double w = 0.0;
                    if (s['weight'] != null) {
                      w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
                    }
                    _weightControllers[i].text = w == 0.0 ? '' : w.toString();
                    debugPrint('LogEntry: mapping cachedSets[$i].weight=$w -> controller[$i]');
                  } catch (_) {}
                }
                setState(() {});
                return;
              }
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('LogEntry: cache read failed: $e');
      }

      List<dynamic> logs = [];
      try {
        logs = await _pb.fetchLogsForExercise(widget.athleteId, widget.planId, widget.exerciseId, perPage: 1);
      } catch (e) {
        debugPrint('LogEntry: fetchLogsForExercise failed: $e');
        logs = [];
      }
      debugPrint('LogEntry: fetched logs count=${logs.length}');
      if (logs.isEmpty) return;
      final latest = logs.first as Map<String, dynamic>;
      // Support a few shapes where `sets` might live (direct field, nested
      // inside `data`, or inside a `record` wrapper). Normalize helper will
      // decode stringified JSON as needed.
      dynamic setsField;
      if (latest.containsKey('sets')) setsField = latest['sets'];
      else if (latest.containsKey('data') && latest['data'] is Map && latest['data'].containsKey('sets')) setsField = latest['data']['sets'];
      else if (latest.containsKey('record') && latest['record'] is Map && latest['record'].containsKey('sets')) setsField = latest['record']['sets'];
      else setsField = null;

      final savedSets = _pb.normalizeSetsField(setsField);
      debugPrint('LogEntry: fetched latest sets count=${savedSets.length} raw=$setsField');
      // If the stored log used a numeric sets count rather than a list, try
      // to derive controller count from it.
      if ((setsField is num) || (setsField is String && int.tryParse(setsField) != null)) {
        final parsedCount = (setsField is num) ? setsField.toInt() : int.tryParse(setsField) ?? _setsCount;
        if (parsedCount > 0 && parsedCount != _setsCount) {
          _setsCount = parsedCount;
          _ensureControllersCount();
        }
      }
      if (savedSets.isEmpty) return;
      // Map saved sets into the current controllers. If the saved log has
      // fewer entries than the plan's `_setsCount`, we map them to the last
      // N sets by default (so a single previous weight fills the final set),
      // which often matches athlete expectations. Toggle
      // `_mapSavedWeightsToLast` to change this behavior.
      try {
        final savedLen = savedSets.length;
        if (_mapSavedWeightsToLast) {
          // Start position so last savedLen entries align to the tail.
          final start = (_setsCount - savedLen) > 0 ? (_setsCount - savedLen) : 0;
          for (var i = 0; i < savedLen && (start + i) < _setsCount; i++) {
            final s = savedSets[i];
            double w = 0.0;
            if (s['weight'] != null) {
              w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
            }
            _weightControllers[start + i].text = w == 0.0 ? '' : w.toString();
            debugPrint('LogEntry: mapping savedSets[$i].weight=$w -> controller[${start + i}]');
          }
        } else {
          for (var i = 0; i < _setsCount && i < savedLen; i++) {
            final s = savedSets[i];
            double w = 0.0;
            if (s['weight'] != null) {
              w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
            }
            _weightControllers[i].text = w == 0.0 ? '' : w.toString();
            debugPrint('LogEntry: mapping savedSets[$i].weight=$w -> controller[$i]');
          }
        }
      } catch (_) {}
      setState(() {});
    } catch (_) {
      // ignore fetch errors
    }
  }

  /// Ensure `_weightControllers` has exactly `_setsCount` entries.
  /// Preserve existing controller values where possible and dispose
  /// any surplus controllers when shrinking.
  void _ensureControllersCount() {
    if (_weightControllers.length == _setsCount) return;
    final newList = <TextEditingController>[];
    final minLen = _weightControllers.length < _setsCount ? _weightControllers.length : _setsCount;
    for (var i = 0; i < minLen; i++) {
      newList.add(_weightControllers[i]);
    }
    for (var i = minLen; i < _setsCount; i++) {
      newList.add(TextEditingController());
    }
    // dispose any extra controllers that won't be preserved
    if (_weightControllers.length > _setsCount) {
      for (var i = _setsCount; i < _weightControllers.length; i++) {
        try { _weightControllers[i].dispose(); } catch (_) {}
      }
    }
    _weightControllers = newList;
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
  }

  void _initVideoIfNeeded() {
    final ex = widget.exercise;
    if (ex == null) return;
    final vid = ex['video'];
    if (vid == null || vid is! Map) return;
    final fileName = vid['file'] as String?;
    final collectionId = vid['collectionId'] as String? ?? vid['collection'] as String?;
    final recordId = vid['id'] as String? ?? vid['_id'] as String?;
    if (fileName == null || collectionId == null || recordId == null) return;
    final url = '${_pb.baseUrl}/api/files/$collectionId/$recordId/$fileName';
    try {
      // Log the URL for debugging so you can curl it from host if needed.
  // Debug logging removed
      _videoController = VideoPlayerController.network(url);
      // store the initialization future and let the UI react to it via FutureBuilder
      _initializeVideoFuture = _videoController!.initialize().then((_) async {
        // ensure audible volume on initialization
        try { await _videoController?.setVolume(1.0); } catch (_) {}
        // optionally loop preview clips
        try { await _videoController?.setLooping(true); } catch (_) {}
        setState(() {});
      }).catchError((e) {
        // initialization error handled by FutureBuilder
      });
    } catch (e) {
      // ignore controller creation errors here; UI will show video not available
    }
  }

  Future<void> _save() async {
    final sets = <Map<String, dynamic>>[];
    // Only include sets where the trainer/athlete actually entered a weight.
    for (var i = 0; i < _setsCount; i++) {
      final raw = _weightControllers[i].text.trim();
      if (raw.isEmpty) continue; // skip empty boxes (partial saves allowed)
      // Support commas as decimal separators for some locales
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
      debugPrint('LogEntry: saving sets=${sets.toString()} for exercise=${widget.exerciseId}');
  await _pb.createLog(widget.athleteId, widget.planId, widget.exerciseId, sets);
      // Print the server response for debugging and optionally show it in a dialog
      debugPrint('LogEntry: createLog called successfully');
      try {
        final sp = await SharedPreferences.getInstance();
        final key = 'last_log_${widget.athleteId}_${widget.exerciseId}';
        await sp.setString(key, jsonEncode(sets));
        debugPrint('LogEntry: cached last log to SharedPreferences key=$key');
      } catch (e) {
        debugPrint('LogEntry: failed to write cache: $e');
      }
      if (!mounted) return;
      // simple confirmation
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log saved')));

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('LogEntry: createLog failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save log')));
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


  // dispose moved earlier to ensure RouteObserver unsubscribed

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
                      decoration: BoxDecoration(color: Theme.of(context).dividerColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                      child: Text(_repsPerSet.toString(), style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(width: 12),
                    // per-set save / status removed — global Save button at bottom is used
                    const SizedBox(width: 0),
                  ],
                ),
              );
            }),

            const SizedBox(height: 18),
            // video placeholder: only show video section when an attached video exists
            if (ex != null && ex['video'] != null) ...[
              Text('Video', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    // Use FutureBuilder to render the player once initialization completes
                    if (_videoController != null)
                      FutureBuilder<void>(
                        future: _initializeVideoFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(color: Theme.of(context).dividerColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8.0)),
                              child: const Center(child: Text('Loading video...')),
                            );
                          } else if (snap.hasError) {
                            return Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(color: Theme.of(context).dividerColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8.0)),
                              child: Center(child: Text('Video failed to load: ${snap.error}')),
                            );
                          } else if (_videoController!.value.isInitialized) {
                            return AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            );
                          } else {
                            return Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(color: Theme.of(context).dividerColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8.0)),
                              child: const Center(child: Text('Video not available')),
                            );
                          }
                        },
                      )
                    else
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(color: Theme.of(context).dividerColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8.0)),
                        child: const Center(child: Text('No video attached')),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        IconButton(
                          icon: Icon(_videoController != null && _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (_videoController == null) return;
                            setState(() {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.fullscreen),
                          onPressed: () {
                            // Build file URL and open fullscreen player
                            try {
                              final vid = ex['video'];
                              final fileName = vid['file'] as String?;
                              final collectionId = vid['collectionId'] as String? ?? vid['collection'] as String?;
                              final recordId = vid['id'] as String? ?? vid['_id'] as String?;
                              if (fileName == null || collectionId == null || recordId == null) return;
                              final url = '${_pb.baseUrl}/api/files/$collectionId/$recordId/$fileName';
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullscreenVideoScreen(url: url)));
                            } catch (e) {
                              // debug logging removed
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              )
            ],
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

/// A simple fullscreen video player screen used for previewing stored videos.
class FullscreenVideoScreen extends StatefulWidget {
  final String url;
  const FullscreenVideoScreen({Key? key, required this.url}) : super(key: key);

  @override
  _FullscreenVideoScreenState createState() => _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends State<FullscreenVideoScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    try {
      _controller = VideoPlayerController.network(widget.url);
      _initFuture = _controller!.initialize().then((_) async {
        try { await _controller?.setVolume(1.0); } catch (_) {}
        try { await _controller?.setLooping(false); } catch (_) {}
        _controller?.play();
        setState(() {});
      }).catchError((e) { /* ignore init errors - UI will show them */ });
    } catch (e) {
      // ignore create errors
    }
  }

  @override
  void dispose() {
    try { _controller?.dispose(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
  appBar: AppBar(backgroundColor: Theme.of(context).appBarTheme.backgroundColor, elevation: 0),
      body: Center(
        child: _controller == null
            ? Text('No video', style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white))
            : FutureBuilder<void>(
                future: _initFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snap.hasError) {
                    return Text('Failed to load: ${snap.error}', style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white));
                  } else if (_controller!.value.isInitialized) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller!.value.isPlaying) _controller!.pause(); else _controller!.play();
                        });
                      },
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    );
                  } else {
                    return Text('Video not available', style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white));
                  }
                },
              ),
      ),
    );
  }
}
