import 'package:flutter/material.dart';
import '../services/athleteService.dart';
import '../models/athlete.dart';
import '../widgets/account_action.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AthleteService _athleteService = AthleteService();
  List<Athlete> athletes = [];

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  void _loadAthletes() async {
    List<Athlete> fetched = await _athleteService.getAthletes();
    setState(() {
      athletes = fetched;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Dashboard'), actions: [Padding(padding: const EdgeInsets.only(right:8.0), child: AccountAction())]),
      body: ListView.builder(
        itemCount: athletes.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(athletes[index].name),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open form to create new athlete
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
