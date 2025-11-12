import 'package:flutter/material.dart';
// trainer_dashboard is a lightweight landing page; heavy-lifting done in ManageAthletesScreen
import 'manage_athletes.dart';
import 'manage_templates_list.dart';
import '../widgets/account_action.dart';

import '../services/pocketbase_service.dart';


class TrainerDashboard extends StatefulWidget {
  final String trainerId;
  const TrainerDashboard({Key? key, required this.trainerId}) : super(key: key);

  @override
  _TrainerDashboardState createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  bool _loading = true;
  String _displayName = '';
  final _pb = PocketBaseService();

  @override
  void initState() {
    super.initState();
    _load();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _pb.getUserById(widget.trainerId);
      if (!mounted) return;
      setState(() => _displayName = (user['displayName'] ?? '').toString());
    } catch (_) {}
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Trainer Dashboard'),
        actions: [Padding(padding: const EdgeInsets.only(right: 8.0), child: AccountAction(displayName: _displayName))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Welcome, ${_displayName.isNotEmpty ? _displayName : 'trainer'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManageAthletesScreen(trainerId: widget.trainerId)));
                    },
                    icon: const Icon(Icons.group),
                    label: const Text('Manage athletes'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManageTemplatesListScreen(trainerId: widget.trainerId)));
                    },
                    icon: const Icon(Icons.library_books),
                    label: const Text('Manage templates'),
                  ),
                ],
              ),
            ),
    );
  }
}

// Athlete detail screen is now in ManageAthletesScreen for separation of concerns.
