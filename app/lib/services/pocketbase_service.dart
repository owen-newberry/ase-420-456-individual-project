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

  Future<void> _restoreToken() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _authToken = sp.getString(_tokenKey);
    } catch (_) {
      // ignore failures to restore
    }
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
      throw HttpException('Auth failed: ${res.statusCode} ${res.reasonPhrase}');
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
      final rb = res.body.isNotEmpty ? res.body : res.reasonPhrase;
      throw HttpException('Sign up failed: ${res.statusCode} $rb');
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
    final url = Uri.parse('$baseUrl/api/collections/logs/records');
    final body = jsonEncode({
      'athlete': athleteId,
      'plan': planId,
      'exerciseId': exerciseId,
      'sets': sets,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final res = await http.post(url, headers: _jsonHeaders, body: body);
    if (res.statusCode != 200 && res.statusCode != 201) throw HttpException('Create log failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String,dynamic>;
  }

  /// Upload a video file. Creates a video record and uploads the file field.
  /// Returns the created video record JSON.
  Future<Map<String, dynamic>> uploadVideo(String title, String filePath) async {
    // create record
    final createUrl = Uri.parse('$baseUrl/api/collections/videos/records');
    final createBody = jsonEncode({'title': title});
    final createRes = await http.post(createUrl, headers: _jsonHeaders, body: createBody);
    if (createRes.statusCode != 200 && createRes.statusCode != 201) {
      final body = createRes.body.isNotEmpty ? createRes.body : createRes.reasonPhrase;
      throw HttpException('Create video record failed: ${createRes.statusCode} $body');
    }
    final video = jsonDecode(createRes.body) as Map<String,dynamic>;
    final recordId = video['id'] as String?;
    if (recordId == null) throw HttpException('Create video record did not return id');

    // upload file
    final uploadUrl = Uri.parse('$baseUrl/api/collections/videos/records/$recordId/files/file');
    final req = http.MultipartRequest('POST', uploadUrl);
    if (_authToken != null) req.headers['Authorization'] = 'Bearer $_authToken';
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

  /// Fetch a video record by id (includes file metadata after upload)
  Future<Map<String, dynamic>> getVideoById(String id) async {
    final url = Uri.parse('$baseUrl/api/collections/videos/records/$id');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode != 200) throw HttpException('Get video failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
