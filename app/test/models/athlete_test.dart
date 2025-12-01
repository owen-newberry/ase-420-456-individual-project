import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/athlete.dart';

void main() {
  group('Athlete model', () {
    test('fromJson properly parses fields', () {
      final json = {'_id': 'abc123', 'name': 'Alice', 'age': 30, 'email': 'a@example.com'};
      final a = Athlete.fromJson(json);
      expect(a.id, 'abc123');
      expect(a.name, 'Alice');
      expect(a.age, 30);
      expect(a.email, 'a@example.com');
    });

    test('toJson excludes id and includes properties', () {
      final a = Athlete(id: 'x', name: 'Bob', age: 25, email: 'b@example.com');
      final j = a.toJson();
      expect(j.containsKey('name'), isTrue);
      expect(j['name'], 'Bob');
      expect(j.containsKey('age'), isTrue);
      expect(j['age'], 25);
      expect(j.containsKey('email'), isTrue);
      expect(j['email'], 'b@example.com');
      expect(j.containsKey('_id'), isFalse);
    });
  });
}
