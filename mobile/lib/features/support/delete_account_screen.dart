import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/password_field.dart';
import '../auth/data/auth_repository.dart';

/// Settings > Delete account (both roles). Explains exactly what happens,
/// asks for the password, and on success clears the local session and
/// returns to Welcome. The backend refuses while the account still has an
/// open job, a pending bid or an active assignment — that message is shown
/// here as-is so the user knows what to finish first.
class DeleteAccountScreen extends StatefulWidget {
  DeleteAccountScreen({super.key, AuthRepository? authRepository, SessionStore? sessionStore})
    : authRepository = authRepository ?? AuthRepository(),
      sessionStore = sessionStore ?? SessionStore();

  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  bool _isDeleting = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorText = l10n.enterYourPassword);
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorText = null;
    });

    try {
      await widget.authRepository.deleteAccount(currentPassword: password);
      await widget.sessionStore.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.accountDeletedMessage)));
      context.go('/welcome');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorText = e.firstErrorFor('current_password') ?? e.firstErrorFor('account') ?? e.message);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountLabel)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.warning_amber_rounded, size: 40, color: AppColors.statusError),
            const SizedBox(height: 12),
            Text(l10n.deleteAccountWarning, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(l10n.deleteAccountBlockedHint, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            PasswordField(
              controller: _passwordController,
              labelText: l10n.currentPasswordHint,
              onSubmitted: (_) => _delete(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(_errorText!, style: TextStyle(color: AppColors.statusError)),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isDeleting ? null : _delete,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusError, foregroundColor: Colors.white),
              child: _isDeleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.deleteAccountConfirmButton),
            ),
          ],
        ),
      ),
    );
  }
}
