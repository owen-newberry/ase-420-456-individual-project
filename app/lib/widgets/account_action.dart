import 'package:flutter/material.dart';
import '../screens/select_role.dart';
import '../screens/account.dart';
import '../services/pocketbase_service.dart';

class AccountAction extends StatelessWidget {
  final String? displayName;
  final VoidCallback? onSignOut;

  const AccountAction({Key? key, this.displayName, this.onSignOut}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = displayName ?? 'Account';
    final initials = name.isNotEmpty ? name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join() : 'A';

    return PopupMenuButton<String>(
      tooltip: 'Account',
      icon: CircleAvatar(child: Text(initials)),
      onSelected: (v) async {
        if (v == 'signout') {
          // Clear any auth state if necessary, then navigate to sign in.
          if (onSignOut != null) {
            onSignOut!();
            return;
          }
          // Default sign out: clear persisted token and navigate to sign in.
          try {
            await PocketBaseService().signOut();
          } catch (_) {}
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SelectRoleScreen()), (r) => false);
        } else if (v == 'profile') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'profile', child: Text('Profile')),
        PopupMenuItem(value: 'signout', child: Text('Sign out')),
      ],
    );
  }
}
