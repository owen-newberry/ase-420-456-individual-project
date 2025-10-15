import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/athlete.dart';

class AthleteService {
  final String baseUrl = "http://localhost:3000/api/athletes"; // Replace with your backend URL

  Future<List<Athlete>> getAthletes() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List jsonData = json.decode(response.body);
      return jsonData.map((athlete) => Athlete.fromJson(athlete)).toList();
    } else {
      throw Exception('Failed to load athletes');
    }
  }

  Future<Athlete> createAthlete(Athlete athlete) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(athlete.toJson()),
    );

    if (response.statusCode == 201) {
      return Athlete.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create athlete');
    }
  }

  Future<Athlete> updateAthlete(String id, Athlete athlete) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(athlete.toJson()),
    );

    if (response.statusCode == 200) {
      return Athlete.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update athlete');
    }
  }

  Future<void> deleteAthlete(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete athlete');
    }
  }
}
