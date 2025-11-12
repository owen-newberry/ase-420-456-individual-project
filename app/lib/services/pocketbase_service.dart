import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A small REST-based PocketBase client tailored to the app's needs.
/// Using REST keeps behavior explicit and decouples us from SDK API changes.
class PocketBaseService {
  // Use 10.0.2.2 for Android emulator to reach host localhost
  String baseUrl;

  String? _authToken;
  String? _currentUserId;
  static const String _tokenKey = 'pb_token';
  static const String _userIdKey = 'pb_user_id';
  bool _tokenLoaded = false;

  // Singleton instance
  static final PocketBaseService _instance = PocketBaseService._internal('http://10.0.2.2:8090');

  /// Returns the shared PocketBaseService instance. Passing [baseUrl]
  /// will update the instance's baseUrl (useful for tests or non-emulator runs).
  factory PocketBaseService({String baseUrl = 'http://10.0.2.2:8090'}) {
    _instance.baseUrl = baseUrl;
    return _instance;
  }

  PocketBaseService._internal(this.baseUrl) {
    // restore token asynchronously (non-blocking)
    _restoreToken();
  }

  void _logAndThrow(http.Response res, String context) {
    // Print response body (if any) to help diagnose 4xx/5xx failures during
    // development. We keep this lightweight and tolerant of errors.
    // debug printing removed
    final rb = (res.body.isNotEmpty) ? res.body : res.reasonPhrase;
    throw HttpException('$context failed: ${res.statusCode} $rb');
  }

  Future<void> _restoreToken() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _authToken = sp.getString(_tokenKey);
      _currentUserId = sp.getString(_userIdKey);
      _tokenLoaded = true;
    } catch (_) {
      // ignore failures to restore
    }
  }

  /// Ensure we've attempted to load a persisted token before making requests.
  Future<void> _ensureTokenLoaded() async {
    if (_tokenLoaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      _authToken = sp.getString(_tokenKey);
      _currentUserId = sp.getString(_userIdKey);
    } catch (_) {}
    _tokenLoaded = true;
  }

  Map<String, String> get _jsonHeaders {
    final headers = { 'Content-Type': 'application/json' };
    if (_authToken != null) headers['Authorization'] = 'Bearer $_authToken';
    return headers;
  }

  /// Sign in a user (athlete or trainer). Returns the user record JSON on success.
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/collections/users/auth-with-password');
    final body = jsonEncode({'identity': email, 'password': password});
    final res = await http.post(url, headers: { 'Content-Type': 'application/json' }, body: body);
    if (res.statusCode != 200) {
      _logAndThrow(res, 'Auth');
    }
    final data = jsonDecode(res.body) as Map<String,dynamic>;
    // Try to extract token from several possible shapes returned by PocketBase
    String? token;
    try {
      if (data.containsKey('token')) {
        final t = data['token'];
        if (t is String) token = t;
        else if (t is Map && (t['access'] != null || t['accessToken'] != null)) {
          token = t['access'] ?? t['accessToken'];
        }
      }
      token ??= data['accessToken'] ?? data['access_token'] ?? data['token'] as String?;
    } catch (_) {
      // ignore parsing issues here; token may remain null
    }
    _authToken = token;
    // try extract user id from response record
    try {
      String? userId;
      if (data['record'] != null && data['record']['id'] != null) userId = data['record']['id'] as String?;
      userId ??= data['id'] as String?;
      _currentUserId = userId;
    } catch (_) {}
    // persist token for later app restarts
    try {
      final sp = await SharedPreferences.getInstance();
      if (_authToken != null) await sp.setString(_tokenKey, _authToken!);
      if (_currentUserId != null) await sp.setString(_userIdKey, _currentUserId!);
    } catch (_) {}
    return data;
  }

  /// Sign up a new user. Creates a user record in the `users` collection
  /// and then signs them in to obtain an auth token. Returns a map with
  /// the created record under `created` and the sign-in response under `auth`.
  /// Create a new user. [displayName] and [role] map to the app schema
  /// (displayName, role). [trainerId] can be provided when creating an
  /// athlete that belongs to a trainer.
  Future<Map<String, dynamic>> signUp(String email, String password, {String? displayName, String role = 'athlete', String? trainerId}) async {
    final url = Uri.parse('$baseUrl/api/collections/users/records');
    final body = jsonEncode({
      'email': email,
      'password': password,
      // PocketBase often expects a password confirmation field on public create
      'passwordConfirm': password,
      if (displayName != null) 'displayName': displayName,
      if (role.isNotEmpty) 'role': role,
      if (trainerId != null) 'trainer': trainerId,
    });
    final res = await http.post(url, headers: { 'Content-Type': 'application/json' }, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      _logAndThrow(res, 'Sign up');
    }
    final created = jsonDecode(res.body) as Map<String, dynamic>;

    // Attempt to sign the user in so we obtain and persist the token.
    // Attempt to sign the user in so we obtain and persist the token.
    Map<String, dynamic>? auth;
    try {
      auth = await signIn(email, password);
    } catch (e) {
      // If sign-in fails after create, return the created record and the
      // sign-in error message in `auth` for UI to surface.
      auth = {'error': e.toString()};
    }
    return {'created': created, 'auth': auth};
  }

  Future<void> signOut() async {
    _authToken = null;
    _currentUserId = null;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_tokenKey);
      await sp.remove(_userIdKey);
    } catch (_) {}
  }

  /// Return the currently persisted user id (if any). Loads persisted token/user id if not loaded.
  Future<String?> getCurrentUserId() async {
    await _ensureTokenLoaded();
    return _currentUserId;
  }

  /// Fetch all plans for a given athlete on a specific date (YYYY-MM-DD).
  Future<List<dynamic>> fetchPlanForDate(String athleteId, String date) async {
    await _ensureTokenLoaded();
    final filter = Uri.encodeQueryComponent('athlete = "$athleteId" && date = "$date"');
    final url = Uri.parse('$baseUrl/api/collections/plans/records?filter=$filter');
  final res = await http.get(url, headers: _jsonHeaders);
  if (res.statusCode != 200) _logAndThrow(res, 'Fetch plans');
  final data = jsonDecode(res.body) as Map<String,dynamic>;
    // PocketBase returns items in `items` for list endpoints
    return data['items'] as List<dynamic>? ?? [];
  }

  /// Create a workout log for an athlete.
  Future<Map<String, dynamic>> createLog(String athleteId, String planId, String exerciseId, List<Map<String, dynamic>> sets) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in before creating logs');
    final url = Uri.parse('$baseUrl/api/collections/logs/records');
    final body = jsonEncode({
      'athlete': athleteId,
      'plan': planId,
      'exerciseId': exerciseId,
      // PocketBase schema stores `sets` as serialized JSON text in our project.
      // Ensure we stringify lists/maps so the DB consistently stores a text blob.
      'sets': (sets is String) ? sets : jsonEncode(sets),
      'createdAt': DateTime.now().toIso8601String(),
    });
    final res = await http.post(url, headers: _jsonHeaders, body: body);
  if (res.statusCode != 200 && res.statusCode != 201) _logAndThrow(res, 'Create log');
    return jsonDecode(res.body) as Map<String,dynamic>;
  }

  /// Fetch logs for a specific athlete/plan/exercise. Returns list of log records sorted by createdAt desc.
  Future<List<dynamic>> fetchLogsForExercise(String athleteId, String planId, String exerciseId, {int perPage = 20}) async {
    await _ensureTokenLoaded();

    // First try: include the plan filter. This works when the server stores
    // the `plan` relation as a single id value. If the server stores the
    // relation as an array or another shape the filter may return no items,
    // so we fall back to a broader query below.
    final planFilter = Uri.encodeQueryComponent('athlete = "$athleteId" && plan = "$planId" && exerciseId = "$exerciseId"');
    var url = Uri.parse('$baseUrl/api/collections/logs/records?filter=$planFilter&perPage=$perPage&sort=-createdAt');
    var res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) _logAndThrow(res, 'Fetch logs (plan filter)');
    var data = jsonDecode(res.body) as Map<String,dynamic>;
    var items = data['items'] as List<dynamic>? ?? [];

    if (items.isNotEmpty) return items;

    // Fallback: query by athlete + exercise only so we still obtain recent
    // logs even if the `plan` filter didn't match due to relation shape.
    final fallbackFilter = Uri.encodeQueryComponent('athlete = "$athleteId" && exerciseId = "$exerciseId"');
    url = Uri.parse('$baseUrl/api/collections/logs/records?filter=$fallbackFilter&perPage=$perPage&sort=-createdAt');
    res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) _logAndThrow(res, 'Fetch logs (fallback)');
    data = jsonDecode(res.body) as Map<String,dynamic>;
    return data['items'] as List<dynamic>? ?? [];
  }

  /// Normalize a `sets` field from a log record into a List<Map> with
  /// numeric `weight` values where possible.
  ///
  /// PocketBase records in this project may store `sets` either as a
  /// JSON-encoded string or as a native list (depending on how the record
  /// was created). This helper handles both shapes and coerces the
  /// `weight` value to a double when possible so UI code can rely on
  /// numeric types.
  List<Map<String, dynamic>> normalizeSetsField(dynamic setsRaw) {
    List<dynamic> parsed = [];
    if (setsRaw == null) return <Map<String, dynamic>>[];

    // Defensive decoding: some records are stored as JSON-encoded strings
    // and some may have been double-encoded (a string containing escaped
    // JSON). Attempt repeated decoding up to a few times to recover the
    // actual list shape.
    dynamic working = setsRaw;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (working is List) {
        parsed = working;
        break;
      }
      if (working is String) {
        try {
          final p = jsonDecode(working);
          // If decoding yields a list, we're done. If it yields another
          // string (double-encoded) we'll loop and try again.
          working = p;
          if (working is List) {
            parsed = working;
            break;
          }
        } catch (_) {
          // not valid JSON string, break and treat as empty
          working = null;
          break;
        }
      } else {
        // unknown shape, break
        break;
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final s in parsed) {
      try {
        if (s is Map) {
          final m = Map<String, dynamic>.from(s);
          final wraw = m['weight'];
          double? w;
          if (wraw is num) w = wraw.toDouble();
          else w = double.tryParse(wraw?.toString() ?? '');
          if (w != null) m['weight'] = w;
          out.add(m);
        }
      } catch (_) {
        // ignore malformed set entries
      }
    }
    return out;
  }

  /// Upload a video file. Creates a video record and uploads the file field.
  /// Returns the created video record JSON.
  /// Upload a video. Provide either [filePath] (preferred when available) or
  /// provide [bytes] and [filename] when the platform returns the file contents
  /// directly (some pickers on certain platforms do this). Returns the created
  /// video record JSON (refetched after upload to include file metadata).
  Future<Map<String, dynamic>> uploadVideo(String title, {String? description, String? filePath, Uint8List? bytes, String? filename}) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in before uploading videos');
    // Use a single multipart CREATE request (title, description, file) rather
    // than creating an empty record and uploading the file afterward. Some
    // PocketBase setups (and our test instance) reject or 404 the separate
    // file-upload endpoint; submitting the file during create is more
    // portable and avoids an extra round-trip.
    final createUrl = Uri.parse('$baseUrl/api/collections/videos/records');
    final req = http.MultipartRequest('POST', createUrl);
    if (_authToken != null) req.headers['Authorization'] = 'Bearer ${_authToken}';
    req.fields['title'] = title;
    if (description != null) req.fields['description'] = description;

    if (bytes != null) {
      final name = filename ?? 'upload.mp4';
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    } else if (filePath != null && filePath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('file', filePath));
    } else {
      throw ArgumentError('Either filePath or bytes+filename must be provided for upload');
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    // debug logging removed
    if (res.statusCode != 200 && res.statusCode != 201) {
      _logAndThrow(res, 'Create+upload video');
    }

    // Return the created record JSON as provided by the server
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Update an existing video record's `file` field by uploading a new file for it.
  /// Returns the updated video record JSON.
  Future<Map<String, dynamic>> updateVideoFile(String recordId, {String? filePath, Uint8List? bytes, String? filename}) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in before uploading videos');
    final uploadUrl = Uri.parse('$baseUrl/api/collections/videos/records/$recordId/files/file');
    final req = http.MultipartRequest('POST', uploadUrl);
    req.headers['Authorization'] = 'Bearer ${_authToken}';

    if (bytes != null) {
      final name = filename ?? 'upload.mp4';
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    } else if (filePath != null && filePath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('file', filePath));
    } else {
      throw ArgumentError('Either filePath or bytes+filename must be provided for upload');
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    // debug logging removed
    if (res.statusCode != 200 && res.statusCode != 201) {
      _logAndThrow(res, 'Update video file');
    }

    // return refreshed video record
    return await getVideoById(recordId);
  }

  /// Patch video record metadata (title/description).
  Future<Map<String, dynamic>> updateVideoMetadata(String recordId, {String? title, String? description}) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in before updating videos');
    final url = Uri.parse('$baseUrl/api/collections/videos/records/$recordId');
    final headers = Map<String,String>.from(_jsonHeaders);
    headers['Content-Type'] = 'application/json';
    final body = jsonEncode({
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    });
    final res = await http.patch(url, headers: headers, body: body);
    if (res.statusCode != 200) _logAndThrow(res, 'Update video metadata');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetch a user (record) by id from the `users` collection.
  Future<Map<String, dynamic>> getUserById(String id) async {
    final url = Uri.parse('$baseUrl/api/collections/users/records/$id');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) throw HttpException('Get user failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetch athletes for a trainer (users with role='athlete' and trainer relation set)
  Future<List<dynamic>> fetchAthletesForTrainer(String trainerId) async {
    // PocketBase may store relations in different shapes depending on how the
    // record was created (string id, map with `id`, list of ids, or even a
    // JSON-encoded string). To be robust, fetch athletes and filter client
    // side for any trainer shape that references the trainerId.
    // Additionally, some existing records may reference the trainer by email
    // (not id). Fetch the trainer record to obtain the trainer email to use
    // as a fallback comparison when the athlete `trainer` field is a string.
    String? trainerEmail;
    try {
      final t = await getUserById(trainerId);
      trainerEmail = t['email'] as String?;
    } catch (_) {
      // ignore - fallback to id-only matching
      trainerEmail = null;
    }
    // Debug: log inputs
  // debug logging removed
  // Ensure token is loaded before making authenticated requests.
  await _ensureTokenLoaded();

  // First attempt: ask the server for users whose trainer equals trainerId.
    // This should be efficient and handle relation fields stored as the
    // trainer's record id (most common shape).
    final trainerFilter = Uri.encodeQueryComponent('trainer = "$trainerId"');
    final serverUrl = Uri.parse('$baseUrl/api/collections/users/records?filter=$trainerFilter&perPage=200');
    try {
      final serverRes = await http.get(serverUrl, headers: _jsonHeaders);
      if (serverRes.statusCode == 200) {
        final serverData = jsonDecode(serverRes.body) as Map<String, dynamic>;
        final serverItems = serverData['items'] as List<dynamic>? ?? [];
  // debug logging removed
        if (serverItems.isNotEmpty) {
          // Return server-filtered results (they should already be athlete users)
          return serverItems;
        }
        // else fall through to a client-side fetch+filter as a fallback
      } else {
  // debug logging removed
      }
    } catch (e) {
  // debug logging removed
    }

    // Fallback: fetch all users (no role filter) and filter client-side. Some records
    // in the existing DB may not have role='athlete' set, but they will have
    // a `trainer` relation. Fetching all users avoids missing those cases when
    // the server-side filter didn't return results (permission/config edge cases).
    final url = Uri.parse('$baseUrl/api/collections/users/records?perPage=200');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) throw HttpException('Fetch users failed: ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];

    List<dynamic> filtered = [];
    for (final raw in items) {
      try {
        if (raw is! Map<String, dynamic>) continue;
        // Sometimes the list endpoint omits relation fields due to rules or
        // projection; if `trainer` is missing/null we fetch the full record
        // for that user to inspect the field directly.
        var trainerField = raw['trainer'];
        if (trainerField == null) {
          try {
            final full = await getUserById(raw['id'] as String);
            trainerField = full['trainer'];
            // debug logging removed
          } catch (_) {
            // ignore; we'll treat trainerField as null
          }
        }
        bool matches = false;

        // case: direct string id or email
        if (trainerField is String) {
          final trimmed = trainerField.trim();
          if (trimmed == trainerId) {
            matches = true;
          } else if (trainerEmail != null && trimmed == trainerEmail) {
            matches = true;
          } else {
            // maybe it's a JSON encoded string (rare) - attempt to parse
            try {
              final parsed = jsonDecode(trainerField);
              if (parsed is String && (parsed == trainerId || (trainerEmail != null && parsed == trainerEmail))) matches = true;
              else if (parsed is Map) {
                final idVal = parsed['id'] ?? parsed[r'$id'] ?? parsed['value'];
                if (idVal is String && idVal == trainerId) matches = true;
                if (!matches && trainerEmail != null && (parsed['email'] == trainerEmail || parsed['value'] == trainerEmail)) matches = true;
              } else if (parsed is List) {
                for (final e in parsed) {
                  if (e is String && e == trainerId) { matches = true; break; }
                  if (e is Map) {
                    final idVal = e['id'] ?? e[r'$id'] ?? e['value'];
                    if (idVal is String && idVal == trainerId) { matches = true; break; }
                    if (!matches && trainerEmail != null && (e['email'] == trainerEmail || e['value'] == trainerEmail)) { matches = true; break; }
                  }
                }
              }
            } catch (_) {
              // ignore parse errors - leave matches as-is
            }
          }
        }

        // case: map/object with id
        else if (trainerField is Map) {
          final idVal = trainerField['id'] ?? trainerField[r'$id'] ?? trainerField['value'];
          if (idVal is String && idVal.trim() == trainerId) matches = true;
          if (!matches && trainerEmail != null && ((trainerField['email'] ?? trainerField['value']) == trainerEmail)) matches = true;
        }

        // case: list of ids or list of maps
        else if (trainerField is List) {
          for (final e in trainerField) {
            if (e is String && e.trim() == trainerId) { matches = true; break; }
            if (e is Map) {
              final idVal = e['id'] ?? e[r'$id'] ?? e['value'];
              if (idVal is String && idVal.trim() == trainerId) { matches = true; break; }
              if (!matches && trainerEmail != null && ((e['email'] ?? e['value']) == trainerEmail)) { matches = true; break; }
            }
          }
        }

        if (matches) filtered.add(raw);
      } catch (_) {
        // ignore malformed entries
      }
    }

  // debug logging removed
    return filtered;
  }

  /// Fetch all athlete records (no trainer filtering) - useful for debugging.
  Future<List<dynamic>> fetchAllAthleteRecords({int perPage = 200}) async {
    final filter = Uri.encodeQueryComponent('role = "athlete"');
    final url = Uri.parse('$baseUrl/api/collections/users/records?filter=$filter&perPage=$perPage');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) throw HttpException('Fetch athletes failed: ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['items'] as List<dynamic>? ?? [];
  }

  /// Create an athlete record as the authenticated trainer. The trainer must be signed in.
  Future<Map<String, dynamic>> createAthlete(String email, String password, {String? displayName, required String trainerId}) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in as a trainer to create athletes');
    final url = Uri.parse('$baseUrl/api/collections/users/records');
    final body = jsonEncode({
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'displayName': displayName ?? '',
      'role': 'athlete',
      'trainer': trainerId,
    });
    final headers = Map<String,String>.from(_jsonHeaders);
    headers['Content-Type'] = 'application/json';
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      _logAndThrow(res, 'Create athlete');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetch all plans for an athlete (no date filter)
  Future<List<dynamic>> fetchPlansForAthlete(String athleteId) async {
    final filter = Uri.encodeQueryComponent('athlete = "$athleteId"');
    final url = Uri.parse('$baseUrl/api/collections/plans/records?filter=$filter&perPage=200');
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to fetch plans');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) _logAndThrow(res, 'Fetch plans');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['items'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createPlan(String athleteId, String date, List<dynamic> exercises, {String? createdBy}) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to create plans');
    final url = Uri.parse('$baseUrl/api/collections/plans/records');
    // Ensure exercises is stored as a JSON string in the DB for consistency
    final exercisesField = (exercises is String) ? exercises : jsonEncode(exercises);
    final body = jsonEncode({
      'athlete': athleteId,
      'date': date,
      'exercises': exercisesField,
      if (createdBy != null) 'createdBy': createdBy,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final headers = Map<String,String>.from(_jsonHeaders);
    headers['Content-Type'] = 'application/json';
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      _logAndThrow(res, 'Create plan');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePlan(String planId, Map<String, dynamic> updates) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to update plans');
    final url = Uri.parse('$baseUrl/api/collections/plans/records/$planId');
    final headers = Map<String,String>.from(_jsonHeaders);
    headers['Content-Type'] = 'application/json';
    // Ensure exercises is serialized as a JSON string when present in updates
    final updatesCopy = Map<String, dynamic>.from(updates);
    if (updatesCopy.containsKey('exercises')) {
      final ex = updatesCopy['exercises'];
      if (ex is String) {
        // leave as-is
      } else {
        try {
          updatesCopy['exercises'] = jsonEncode(ex);
        } catch (_) {
          // fallback: ensure a safe empty array string rather than null
          updatesCopy['exercises'] = '[]';
        }
      }
    }
    final res = await http.patch(url, headers: headers, body: jsonEncode(updatesCopy));
    if (res.statusCode != 200) _logAndThrow(res, 'Update plan');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> deletePlan(String planId) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to delete plans');
    final url = Uri.parse('$baseUrl/api/collections/plans/records/$planId');
    final res = await http.delete(url, headers: _jsonHeaders);
    if (res.statusCode != 200 && res.statusCode != 204) _logAndThrow(res, 'Delete plan');
  }

  /// Delete a user (athlete or trainer) by id from the `users` collection.
  /// Requires the authenticated user to have permission to delete users.
  Future<void> deleteUser(String userId) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to delete users');
    final url = Uri.parse('$baseUrl/api/collections/users/records/$userId');
    final res = await http.delete(url, headers: _jsonHeaders);
    if (res.statusCode != 200 && res.statusCode != 204) _logAndThrow(res, 'Delete user');
  }

  /// Alias for deleteUser when intent is to delete an athlete
  Future<void> deleteAthleteById(String id) async => deleteUser(id);

  Future<Map<String, dynamic>> getTemplateById(String id) async {
    final url = Uri.parse('$baseUrl/api/collections/templates/records/$id');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) throw HttpException('Get template failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetch a plan record by id.
  Future<Map<String, dynamic>> getPlanById(String id) async {
    final url = Uri.parse('$baseUrl/api/collections/plans/records/$id');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) throw HttpException('Get plan failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetch templates created by a trainer (optionally filter by trainer id)
  Future<List<dynamic>> fetchTemplatesForTrainer(String trainerId, {int perPage = 200}) async {
    final filter = Uri.encodeQueryComponent('createdBy = "$trainerId"');
    final url = Uri.parse('$baseUrl/api/collections/templates/records?filter=$filter&perPage=$perPage');
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to fetch templates');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) _logAndThrow(res, 'Fetch templates');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['items'] as List<dynamic>? ?? [];
  }

  /// Create a template. `exercises` will be serialized to JSON text in the DB.
  Future<Map<String, dynamic>> createTemplate(String name, List<dynamic> exercises, {String? createdBy}) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to create templates');
    final url = Uri.parse('$baseUrl/api/collections/templates/records');
    final exercisesField = (exercises is String) ? exercises : jsonEncode(exercises);
    final body = jsonEncode({
      'name': name,
      'createdBy': createdBy,
      'exercises': exercisesField,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final headers = Map<String,String>.from(_jsonHeaders);
    headers['Content-Type'] = 'application/json';
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) _logAndThrow(res, 'Create template');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Update an existing template. Ensures `exercises` field is serialized.
  Future<Map<String, dynamic>> updateTemplate(String templateId, Map<String, dynamic> updates) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to update templates');
    final url = Uri.parse('$baseUrl/api/collections/templates/records/$templateId');
    final headers = Map<String,String>.from(_jsonHeaders);
    headers['Content-Type'] = 'application/json';
    final updatesCopy = Map<String, dynamic>.from(updates);
    if (updatesCopy.containsKey('exercises')) {
      final ex = updatesCopy['exercises'];
      if (ex is String) {
        // leave as-is
      } else {
        try {
          updatesCopy['exercises'] = jsonEncode(ex);
        } catch (_) {
          updatesCopy['exercises'] = '[]';
        }
      }
    }
    final res = await http.patch(url, headers: headers, body: jsonEncode(updatesCopy));
    if (res.statusCode != 200) _logAndThrow(res, 'Update template');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Delete a template by id.
  Future<void> deleteTemplate(String templateId) async {
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in to delete templates');
    final url = Uri.parse('$baseUrl/api/collections/templates/records/$templateId');
    final res = await http.delete(url, headers: _jsonHeaders);
    if (res.statusCode != 200 && res.statusCode != 204) _logAndThrow(res, 'Delete template');
  }

  /// Apply a template to an athlete by creating plan records for each day
  /// in the period starting at [startDate] for [weeks] weeks. This implementation
  /// creates one plan per day (weeks * 7 plans) using the template.exercises array.
  Future<void> applyTemplateToAthlete(String templateId, String athleteId, DateTime startDate, int weeks, {String? createdBy}) async {
    final tpl = await getTemplateById(templateId);
    final exercisesRaw = tpl['exercises'];
    List<dynamic> exercises;
    if (exercisesRaw is String) {
      exercises = jsonDecode(exercisesRaw) as List<dynamic>;
    } else if (exercisesRaw is List) {
      exercises = exercisesRaw;
    } else {
      exercises = [];
    }

    // If exercises include a `day` property (0=Sunday..6=Saturday), respect it
    // and only create plans on matching weekdays. If no exercise has `day`,
    // place the full exercise list on the first day of each week only.
  final anyHasDay = exercises.any((e) => e is Map && e.containsKey('day'));
    final totalDays = weeks * 7;
    for (var i = 0; i < totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T').first;

      final dayIndex = date.weekday % 7; // DateTime.weekday: Mon=1..Sun=7 -> map Sun->0

      List<dynamic> todays = [];
      if (anyHasDay) {
        for (final e in exercises) {
          try {
            if (e is Map) {
              final rawDay = e['day'];
              if (rawDay == null) continue;
              int? d;
              if (rawDay is int) d = rawDay;
              else {
                d = int.tryParse(rawDay.toString());
              }
              if (d != null && d == dayIndex) todays.add(e);
            }
          } catch (_) {}
        }
      } else {
        // No day tags: treat the first day of each 7-day block as the template day
        if ((i % 7) == 0) {
          todays = List<dynamic>.from(exercises);
        }
      }

      if (todays.isNotEmpty) {
        await createPlan(athleteId, dateStr, todays, createdBy: createdBy);
      }
    }
  }

  /// Fetch a video record by id (includes file metadata after upload)
  Future<Map<String, dynamic>> getVideoById(String id) async {
    final url = Uri.parse('$baseUrl/api/collections/videos/records/$id');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) throw HttpException('Get video failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
