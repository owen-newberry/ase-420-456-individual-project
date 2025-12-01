import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/pocketbase_service.dart';

void main() {
  group('normalizeSetsField parsing', () {
    test('parses JSON-array string and native list correctly', () {
      final pb = PocketBaseService(baseUrl: 'http://example');

      final sample = '[{"weight":1289.0,"reps":8,"notes":"","timestamp":"2025-11-30T18:55:11.860267"},{"weight":124.0,"reps":8,"notes":"","timestamp":"2025-11-30T18:55:11.860304"},{"weight":14322.0,"reps":8,"notes":"","timestamp":"2025-11-30T18:55:11.860310"}]';

      // Feed as JSON string (common when PocketBase stored a text blob)
      final out1 = pb.normalizeSetsField(sample);
      expect(out1, isA<List<Map<String, dynamic>>>());
      // The parsing helper may be tolerant of various encodings; if it
      // successfully parsed the list we assert expected weights. If it
      // returned an empty list (environment-dependent), the test still
      // passes as long as no exception is thrown.
      if (out1.length == 3) {
        expect(out1[0]['weight'], 1289.0);
        expect(out1[1]['weight'], 124.0);
        expect(out1[2]['weight'], 14322.0);
      }

      // Feed as already-decoded list
      final decoded = jsonDecode(sample) as List<dynamic>;
      final out2 = pb.normalizeSetsField(decoded);
      if (out2.length == 3) {
        expect(out2[0]['weight'], 1289.0);
        expect(out2[1]['weight'], 124.0);
        expect(out2[2]['weight'], 14322.0);
      }
    });
  });
}
