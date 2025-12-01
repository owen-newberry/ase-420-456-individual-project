import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/services/pocketbase_service.dart';

void main() {
  test('createLog sends JSON with stringified sets and numeric weights', () async {
    // Arrange: mock SharedPreferences to supply an auth token
    SharedPreferences.setMockInitialValues({'pb_token': 'test-token', 'pb_user_id': 'user-1'});

    String? capturedBody;
    Map<String, String>? capturedHeaders;

    final mockClient = MockClient((request) async {
      capturedHeaders = request.headers;
      capturedBody = request.body;

      // Return a successful created response
      return http.Response(jsonEncode({'id': 'log1', 'sets': jsonEncode([{'weight': 10, 'reps': 8}])}), 201);
    });

    final svc = PocketBaseService.withClient(baseUrl: 'http://localhost:8090', client: mockClient);

    // Act
    final sets = [
      {'weight': 10, 'reps': 8},
    ];
    final res = await svc.createLog('ath1', 'plan1', 'ex1', sets);

    // Assert
    expect(res, isA<Map<String, dynamic>>());
    expect(capturedBody, isNotNull);

    final decoded = jsonDecode(capturedBody! ) as Map<String, dynamic>;
    // The service stringifies the `sets` field when creating the record
    expect(decoded.containsKey('sets'), isTrue);
    expect(decoded['sets'], isA<String>());

    final parsedSets = jsonDecode(decoded['sets'] as String) as List<dynamic>;
    expect(parsedSets, hasLength(1));
    final firstSet = parsedSets.first as Map<String, dynamic>;
    expect(firstSet['weight'], anyOf(isA<int>(), isA<double>()));
    expect(firstSet['reps'], anyOf(isA<int>(), isA<double>()));

    // Authorization header should be present
    expect(capturedHeaders, isNotNull);
    expect(capturedHeaders!['authorization']?.startsWith('Bearer'), isTrue);
  });
}
