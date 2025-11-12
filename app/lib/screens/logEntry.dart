// dart:convert removed (no longer needed)
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';
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
  }

  Future<void> _populateSavedWeights() async {
    // Prefer parsing planned sets from the plan record every time the page
    // loads. This allows the app to show the intended weights/sets defined
    // in the plan itself. If the plan doesn't include weights, we still
    // leave boxes empty so athletes can enter values.
    try {
      final plan = await _pb.getPlanById(widget.planId);
      var exercisesRaw = plan['exercises'];
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
            for (var i = 0; i < _setsCount && i < planSets.length; i++) {
              try {
                final s = planSets[i];
                double w = 0.0;
                if (s['weight'] != null) {
                  w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
                }
                _weightControllers[i].text = w == 0.0 ? '' : w.toString();
              } catch (_) {}
            }
            setState(() {});
            return;
          }
        }
      }

      // If plan didn't provide template weights, fall back to most recent saved log
      final logs = await _pb.fetchLogsForExercise(widget.athleteId, widget.planId, widget.exerciseId, perPage: 1);
      if (logs.isEmpty) return;
      final latest = logs.first as Map<String, dynamic>;
      final savedSets = _pb.normalizeSetsField(latest['sets']);
      if (savedSets.isEmpty) return;
      for (var i = 0; i < _setsCount && i < savedSets.length; i++) {
        try {
          final s = savedSets[i];
          double w = 0.0;
          if (s['weight'] != null) {
            w = (s['weight'] is num) ? (s['weight'] as num).toDouble() : double.tryParse(s['weight'].toString()) ?? 0.0;
          }
          _weightControllers[i].text = w == 0.0 ? '' : w.toString();
        } catch (_) {}
      }
      setState(() {});
    } catch (_) {
      // ignore fetch errors
    }
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
      final created = await _pb.createLog(widget.athleteId, widget.planId, widget.exerciseId, sets);
      // Show the created record so we can confirm how weights were stored on the server
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) {
        return AlertDialog(
          title: const Text('Saved log (server response)'),
          content: SingleChildScrollView(child: SelectableText(const JsonEncoder.withIndent('  ').convert(created))),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
        );
      });
      Navigator.of(context).pop(true);
    } catch (e) {
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


  @override
  void dispose() {
    for (final c in _weightControllers) {
      c.dispose();
    }
    try { _videoController?.dispose(); } catch (_) {}
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
                              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8.0)),
                              child: const Center(child: Text('Loading video...')),
                            );
                          } else if (snap.hasError) {
                            return Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8.0)),
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
                              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8.0)),
                              child: const Center(child: Text('Video not available')),
                            );
                          }
                        },
                      )
                    else
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8.0)),
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
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Center(
        child: _controller == null
            ? const Text('No video', style: TextStyle(color: Colors.white))
            : FutureBuilder<void>(
                future: _initFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snap.hasError) {
                    return Text('Failed to load: ${snap.error}', style: const TextStyle(color: Colors.white));
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
                    return const Text('Video not available', style: TextStyle(color: Colors.white));
                  }
                },
              ),
      ),
    );
  }
}
