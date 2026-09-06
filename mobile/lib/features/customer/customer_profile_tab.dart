import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../auth/data/auth_repository.dart';

/// A deliberately minimal Profile tab, same scope call as
/// CompanyProfileTab: real (working logout), not a placeholder, but no
/// speculative settings/editing UI beyond what's actually needed yet.
class CustomerProfileTab extends StatefulWidget {
  CustomerProfileTab({super.key, AuthRepository? authRepository, SessionStore? sessionStore})
    : authRepository = authRepository ?? AuthRepository(),
      sessionStore = sessionStore ?? SessionStore();

  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await widget.authRepository.logout();
    } finally {
      await widget.sessionStore.clear();
      if (mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: OutlinedButton(
          onPressed: _isLoggingOut ? null : _logout,
          child: _isLoggingOut
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Log out'),
        ),
      ),
    );
  }
}
