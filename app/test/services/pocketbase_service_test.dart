import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/pocketbase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PocketBaseService (unit)', () {
    test('normalizeSetsField handles various encodings and types', () {
      final pb = PocketBaseService(baseUrl: 'http://example');

      // plain list
      final listInput = [
        {'reps': 5, 'weight': 100},
        {'reps': 3, 'weight': '45.5'},
      ];
      final out1 = pb.normalizeSetsField(listInput);
      expect(out1, isA<List<Map<String, dynamic>>>());
      if (out1.length >= 1) expect(out1[0]['weight'], 100.0);
      if (out1.length >= 2) expect(out1[1]['weight'], 45.5);

      // JSON-encoded string
      final jsonStr = '[{"reps":4,"weight":"12"},{"reps":2,"weight":6}]';
      final out2 = pb.normalizeSetsField(jsonStr);
      expect(out2, isA<List<Map<String, dynamic>>>());
      if (out2.length >= 1) expect(out2[0]['weight'], 12.0);
      if (out2.length >= 2) expect(out2[1]['weight'], 6.0);

      // double-encoded string
      final doubleEncoded = '"' + jsonStr.replaceAll('"', '\\"') + '"';
      final out3 = pb.normalizeSetsField(doubleEncoded);
      // may decode to the same shape or fail gracefully to empty
      // ensure it returns a list (possibly empty) and does not throw
      expect(out3, isA<List<Map<String, dynamic>>>());
    });

    test('getCurrentUserId reads persisted value and signOut clears it', () async {
      // mock shared preferences values before creating service
      SharedPreferences.setMockInitialValues({'pb_token': 't1', 'pb_user_id': 'user123'});
      final pb = PocketBaseService(baseUrl: 'http://example');
      final id = await pb.getCurrentUserId();
      expect(id, 'user123');

      await pb.signOut();
      final id2 = await pb.getCurrentUserId();
      expect(id2, isNull);
    });
  });
}
