import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class SignInScreen extends StatefulWidget {
  final String role; // 'athlete' or 'trainer'
  const SignInScreen({Key? key, this.role = 'athlete'}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pb = PocketBaseService();
  bool _loading = false;
  late String _role;

  void _signIn() async {
    setState(() => _loading = true);
    try {
      final data = await _pb.signIn(_emailController.text.trim(), _passwordController.text);
      // extract user id from response
      String? userId;
      if (data['record'] != null && data['record']['id'] != null) userId = data['record']['id'];
      userId ??= data['id'] as String?;
      // Debug: log extracted id and role for tracing
      try {
        print('SignIn: extracted userId=$userId role=$_role from auth response');
      } catch (_) {}
      if (userId == null) throw Exception('No user id returned');
      if (!mounted) return;
      if (_role == 'trainer') {
        Navigator.of(context).pushReplacementNamed('/trainer', arguments: {'trainerId': userId});
      } else {
        Navigator.of(context).pushReplacementNamed('/day', arguments: {'athleteId': userId});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed')));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _role = widget.role;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _signIn, child: const Text('Sign in')),
            const SizedBox(height: 8),
            // Show sign-up only for trainers
            if (_role == 'trainer')
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/signup', arguments: {'role': _role}),
                child: const Text('Create an account'),
              ),
          ],
        ),
      ),
    );
  }
}
