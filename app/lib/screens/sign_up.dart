import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class SignUpScreen extends StatefulWidget {
  final String? initialRole; // if provided, lock role to this value
  const SignUpScreen({Key? key, this.initialRole}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _pb = PocketBaseService();
  bool _loading = false;
  String _role = 'athlete';

  void _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
  final displayName = _nameController.text.trim().isEmpty ? null : _nameController.text.trim();

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _pb.signUp(email, password, displayName: displayName, role: _role);
      final auth = result['auth'] as Map<String, dynamic>?;
      String? userId;
      if (auth != null) {
        if (auth['record'] != null && auth['record']['id'] != null) userId = auth['record']['id'];
        userId ??= auth['id'] as String?;
      }
      userId ??= (result['created'] != null ? (result['created']['id'] as String?) : null);
      if (userId == null) throw Exception('No user id returned after sign up');
      if (!mounted) return;
      // Navigate to trainer dashboard when creating a trainer account, otherwise to athlete day view
      if (_role == 'trainer') {
        Navigator.of(context).pushReplacementNamed('/trainer', arguments: {'trainerId': userId});
      } else {
        Navigator.of(context).pushReplacementNamed('/day', arguments: {'athleteId': userId});
      }
    } catch (e) {
      if (!mounted) return;
      // Show detailed server error body when available for easier debugging
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign up failed: ${e.toString()}')));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialRole != null && widget.initialRole!.isNotEmpty) {
      _role = widget.initialRole!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display name (optional)')),
              const SizedBox(height: 8),
              // If initialRole supplied, hide role selector and use that role.
              if (widget.initialRole == null)
                Row(
                  children: [
                    const Text('Role:'),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _role,
                      items: const [
                        DropdownMenuItem(value: 'athlete', child: Text('Athlete')),
                        DropdownMenuItem(value: 'trainer', child: Text('Trainer')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _role = v);
                      },
                    ),
                  ],
                ),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              TextField(controller: _confirmController, decoration: const InputDecoration(labelText: 'Confirm password'), obscureText: true),
              const SizedBox(height: 20),
              _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _signUp, child: const Text('Sign up')),
            ],
          ),
        ),
      ),
    );
  }
}
