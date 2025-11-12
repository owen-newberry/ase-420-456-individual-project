import 'package:flutter/material.dart';
import 'sign_in.dart';


class SelectRoleScreen extends StatelessWidget {
  const SelectRoleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose role')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _RoleTarget(role: 'trainer')));
                },
                child: const Text('Log in as trainer'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _RoleTarget(role: 'athlete')));
                },
                child: const Text('Log in as athlete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A small bridge widget that navigates to the SignIn screen with the chosen role.
class _RoleTarget extends StatelessWidget {
  final String role;
  const _RoleTarget({Key? key, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SignInScreen(role: role);
  }
}
