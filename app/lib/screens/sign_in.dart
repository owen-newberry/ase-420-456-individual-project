import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pb = PocketBaseService();
  bool _loading = false;

  void _signIn() async {
    setState(() => _loading = true);
    try {
      final data = await _pb.signIn(_emailController.text.trim(), _passwordController.text);
      // extract user id from response
      String? userId;
      if (data['record'] != null && data['record']['id'] != null) userId = data['record']['id'];
      userId ??= data['id'] as String?;
      if (userId == null) throw Exception('No user id returned');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/day', arguments: {'athleteId': userId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed')));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
            _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _signIn, child: const Text('Sign in'))
            ,
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/signup'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
