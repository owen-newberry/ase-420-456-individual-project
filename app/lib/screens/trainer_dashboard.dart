import 'package:flutter/material.dart';
// trainer_dashboard is a lightweight landing page; heavy-lifting done in ManageAthletesScreen
import 'manage_athletes.dart';

class TrainerDashboard extends StatefulWidget {
  final String trainerId;
  const TrainerDashboard({Key? key, required this.trainerId}) : super(key: key);

  @override
  _TrainerDashboardState createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // For the dashboard landing we may fetch a few summary stats later.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: ${e.toString()}')));
    } finally {
      setState(() => _loading = false);
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trainer Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Welcome, trainer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManageAthletesScreen(trainerId: widget.trainerId)));
                    },
                    icon: const Icon(Icons.group),
                    label: const Text('Manage athletes'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(onPressed: () {
                    // placeholder for templates / other trainer actions
                  }, icon: const Icon(Icons.library_books), label: const Text('Manage templates')),
                ],
              ),
            ),
    );
  }
}

// Athlete detail screen is now in ManageAthletesScreen for separation of concerns.
