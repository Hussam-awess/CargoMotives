import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../auth/data/auth_repository.dart';
import 'data/company_repository.dart';

/// A deliberately minimal Profile tab — a real screen, not a placeholder,
/// since the pieces it needs (company name, logout) already exist from
/// Phases 1-2. The fuller profile/settings surface (editing company info,
/// language, etc.) isn't called for by any phase yet, so it isn't built
/// speculatively.
class CompanyProfileTab extends StatefulWidget {
  CompanyProfileTab({
    super.key,
    CompanyRepository? companyRepository,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
  }) : companyRepository = companyRepository ?? CompanyRepository(),
       authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final CompanyRepository companyRepository;
  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<CompanyProfileTab> createState() => _CompanyProfileTabState();
}

class _CompanyProfileTabState extends State<CompanyProfileTab> {
  late Future<CompanyVerification?> _future;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _future = widget.companyRepository.getStatus();
  }

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
      body: FutureBuilder<CompanyVerification?>(
        future: _future,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.data != null) ...[
                Text(
                  snapshot.data!.companyName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Verified transporter company',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 32),
              ],
              OutlinedButton(
                onPressed: _isLoggingOut ? null : _logout,
                child: _isLoggingOut
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Log out'),
              ),
            ],
          );
        },
      ),
    );
  }
}
