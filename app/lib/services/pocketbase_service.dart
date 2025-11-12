import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A small REST-based PocketBase client tailored to the app's needs.
/// Using REST keeps behavior explicit and decouples us from SDK API changes.
class PocketBaseService {
  // Use 10.0.2.2 for Android emulator to reach host localhost
  String baseUrl;

  String? _authToken;
  static const String _tokenKey = 'pb_token';
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
    try {
      print('PocketBase $context failed: status=${res.statusCode} body=${res.body}');
    } catch (_) {}
    final rb = (res.body.isNotEmpty) ? res.body : res.reasonPhrase;
    throw HttpException('$context failed: ${res.statusCode} $rb');
  }

  Future<void> _restoreToken() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _authToken = sp.getString(_tokenKey);
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
    // persist token for later app restarts
    try {
      final sp = await SharedPreferences.getInstance();
      if (_authToken != null) await sp.setString(_tokenKey, _authToken!);
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
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_tokenKey);
    } catch (_) {}
  }

  /// Fetch all plans for a given athlete on a specific date (YYYY-MM-DD).
  Future<List<dynamic>> fetchPlanForDate(String athleteId, String date) async {
    final filter = Uri.encodeQueryComponent('athlete = "$athleteId" && date = "$date"');
    final url = Uri.parse('$baseUrl/api/collections/plans/records?filter=$filter');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) throw HttpException('Fetch plans failed: ${res.statusCode}');
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
      'sets': sets,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final res = await http.post(url, headers: _jsonHeaders, body: body);
  if (res.statusCode != 200 && res.statusCode != 201) _logAndThrow(res, 'Create log');
    return jsonDecode(res.body) as Map<String,dynamic>;
  }

  /// Upload a video file. Creates a video record and uploads the file field.
  /// Returns the created video record JSON.
  Future<Map<String, dynamic>> uploadVideo(String title, String filePath) async {
    // create record
    await _ensureTokenLoaded();
    if (_authToken == null) throw HttpException('Not authenticated: please sign in before uploading videos');
    final createUrl = Uri.parse('$baseUrl/api/collections/videos/records');
    final createBody = jsonEncode({'title': title});
    final createRes = await http.post(createUrl, headers: _jsonHeaders, body: createBody);
    if (createRes.statusCode != 200 && createRes.statusCode != 201) {
      _logAndThrow(createRes, 'Create video record');
    }
    final video = jsonDecode(createRes.body) as Map<String,dynamic>;
    final recordId = video['id'] as String?;
    if (recordId == null) throw HttpException('Create video record did not return id');

    // upload file
    final uploadUrl = Uri.parse('$baseUrl/api/collections/videos/records/$recordId/files/file');
    final req = http.MultipartRequest('POST', uploadUrl);
  // ensure auth header is present for the multipart upload
  req.headers['Authorization'] = 'Bearer ${_authToken}';
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200 && res.statusCode != 201) {
      final body = res.body.isNotEmpty ? res.body : res.reasonPhrase;
      throw HttpException('Upload failed: ${res.statusCode} $body');
    }

    // Return the updated record (refetch to get file metadata)
    return await getVideoById(recordId);
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
    try { print('fetchAthletesForTrainer called with trainerId=$trainerId trainerEmail=$trainerEmail'); } catch (_) {}
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
        try { print('fetchAthletesForTrainer: server filter returned ${serverItems.length} items'); } catch (_) {}
        if (serverItems.isNotEmpty) {
          // Return server-filtered results (they should already be athlete users)
          return serverItems;
        }
        // else fall through to a client-side fetch+filter as a fallback
      } else {
        try { print('fetchAthletesForTrainer: server filter request failed status=${serverRes.statusCode}'); } catch (_) {}
      }
    } catch (e) {
      try { print('fetchAthletesForTrainer: server filter request error: $e'); } catch (_) {}
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
            try { print('fetchAthletesForTrainer: fetched full user ${raw['id']} trainer=${trainerField}'); } catch (_) {}
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

    try { print('fetchAthletesForTrainer: fetched ${items.length} athletes, matched ${filtered.length}'); } catch (_) {}
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
    final body = jsonEncode({
      'athlete': athleteId,
      'date': date,
      'exercises': exercises,
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
    final res = await http.patch(url, headers: headers, body: jsonEncode(updates));
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

    final totalDays = weeks * 7;
    for (var i = 0; i < totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T').first;
      await createPlan(athleteId, dateStr, exercises, createdBy: createdBy);
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
