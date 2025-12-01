import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/services/pocketbase_service.dart';

void main() {
  test('fetchLogsForExercise falls back to client-side recent list when server filters fail', () async {
    SharedPreferences.setMockInitialValues({});

    final athleteId = 'ath1';
    final planId = 'plan1';
    final exerciseId = 'ex1';

    final mockClient = MockClient((request) async {
      final uriStr = request.url.toString();

      // Simulate plan-filtered query failing with 400
      if (uriStr.contains('filter') && uriStr.contains(planId)) {
        return http.Response('{"error":"bad plan filter"}', 400);
      }

      // Simulate fallback filtered query failing with 400
      if (uriStr.contains('filter') && uriStr.contains('exerciseId')) {
        return http.Response('{"error":"bad fallback filter"}', 400);
      }

      // Unfiltered recent list: return items that include one matching record
      if (!uriStr.contains('filter')) {
        final items = [
          {
            'id': 'match1',
            'athlete': athleteId,
            'exerciseId': exerciseId,
            'sets': jsonEncode([
              {'weight': 50, 'reps': 5}
            ])
          },
          {
            'id': 'other',
            'athlete': 'someone-else',
            'exerciseId': exerciseId,
            'sets': jsonEncode([
              {'weight': 20, 'reps': 10}
            ])
          }
        ];
        return http.Response(jsonEncode({'items': items}), 200);
      }

      return http.Response('not found', 404);
    });

    final svc = PocketBaseService.withClient(baseUrl: 'http://localhost:8090', client: mockClient);

    final results = await svc.fetchLogsForExercise(athleteId, planId, exerciseId, perPage: 10);

    expect(results, isA<List<dynamic>>());
    // Should find only the matching athlete+exercise item
    expect(results.length, equals(1));
    final first = results.first as Map<String, dynamic>;
    expect(first['id'], equals('match1'));
  });
}
