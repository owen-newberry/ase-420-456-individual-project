class Athlete {
  final String id;
  final String name;
  final int age;
  final String email;

  Athlete({required this.id, required this.name, required this.age, required this.email});

  factory Athlete.fromJson(Map<String, dynamic> json) {
    return Athlete(
      id: json['_id'],
      name: json['name'],
      age: json['age'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'email': email,
    };
  }
}
