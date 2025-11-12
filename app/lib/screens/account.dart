import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _pb = PocketBaseService();
  bool _loading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = await _pb.getCurrentUserId();
      if (uid == null) throw Exception('No current user');
      final u = await _pb.getUserById(uid);
      if (!mounted) return;
      setState(() => _user = u);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load account: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _pb.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?['displayName'] ?? '';
    final role = (_user?['role'] ?? '').toString();
    final email = _user?['email'] ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${displayName.toString()}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Role: ${role.isNotEmpty ? (role[0].toUpperCase() + role.substring(1)) : 'Unknown'}'),
                  const SizedBox(height: 8),
                  Text('Email: ${email.toString()}'),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _signOut, child: const Text('Sign out')),
                ],
              ),
            ),
    );
  }
}
