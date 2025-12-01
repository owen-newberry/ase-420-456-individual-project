import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/pocketbase_service.dart';

void main() {
  group('PocketBaseService client-side filter', () {
    final pb = PocketBaseService(baseUrl: 'http://example');

    test('filters records with various athlete shapes', () {
      final recent = [
        // athlete as string id
        {'id': 'a1', 'athlete': 'ath1', 'exerciseId': 'ex1'},
        // athlete as map with id
        {'id': 'a2', 'athlete': {'id': 'ath1'}, 'exerciseId': 'ex1'},
        // athlete as list
        {'id': 'a3', 'athlete': ['ath1', 'other'], 'exerciseId': 'ex1'},
        // mismatched athlete
        {'id': 'a4', 'athlete': 'someone', 'exerciseId': 'ex1'},
        // mismatched exercise
        {'id': 'a5', 'athlete': 'ath1', 'exerciseId': 'other'},
        // wrapped in data
        {'id': 'a6', 'data': {'athlete': 'ath1', 'exerciseId': 'ex1'}},
        // wrapped in record
        {'id': 'a7', 'record': {'athlete': {'id': 'ath1'}, 'exerciseId': 'ex1'}},
      ];

      final filtered = pb.filterRecentLogsByAthleteAndExercise(recent, 'ath1', 'ex1');
      // Should include entries with athlete 'ath1' and exerciseId 'ex1'
      final ids = filtered.map((e) => (e as Map<String, dynamic>)['id']).toSet();
      expect(ids, containsAll({'a1', 'a2', 'a3', 'a6', 'a7'}));
      expect(ids, isNot(contains('a4')));
      expect(ids, isNot(contains('a5')));
    });
  });
}
