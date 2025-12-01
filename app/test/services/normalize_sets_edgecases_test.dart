import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/pocketbase_service.dart';

void main() {
  group('normalizeSetsField edge cases', () {
    final pb = PocketBaseService(baseUrl: 'http://example');

    test('parses JSON string with comma decimals and thousands separators', () {
      final input = '[{"weight":"1.234,56","reps":5},{"weight":"2,5","reps":3}]';
      final out = pb.normalizeSetsField(input);
      expect(out, isA<List<Map<String, dynamic>>>());
      if (out.length >= 1) expect(out[0]['weight'], 1234.56);
      if (out.length >= 2) expect(out[1]['weight'], 2.5);
    });

    test('parses native list with numeric and string weights', () {
      final listInput = [
        {'reps': 4, 'weight': 10},
        {'reps': 2, 'weight': '7,5'},
      ];
      final out = pb.normalizeSetsField(listInput);
      expect(out, isA<List<Map<String, dynamic>>>());
      if (out.length >= 1) expect(out[0]['weight'], 10.0);
      if (out.length >= 2) expect(out[1]['weight'], 7.5);
    });

    test('malformed input returns empty list and does not throw', () {
      final bad = '{not a json]';
      final out = pb.normalizeSetsField(bad);
      expect(out, isA<List<Map<String, dynamic>>>());
      expect(out.length, 0);
    });
  });
}
