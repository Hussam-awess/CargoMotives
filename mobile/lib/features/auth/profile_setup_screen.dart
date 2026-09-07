import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../l10n/generated/app_localizations.dart';
import 'data/auth_repository.dart';

/// Customer Profile Setup (AppFlow §1): "name, optional company name ->
/// Customer Home". Only reached for Customer accounts on their first
/// sign-in (requires_profile_setup from the OTP verify response) — a
/// Transporter Company's equivalent step is the verification flow (Phase 2),
/// never this screen.
///
/// Note: the PRD/AppFlow mention an optional "company name" field here, but
/// the Backend Schema's `users` table has no matching column (see
/// ProfileController's docblock on the backend) — omitted for the same
/// reason, not an oversight.
class ProfileSetupScreen extends StatefulWidget {
  ProfileSetupScreen({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? AuthRepository();

  final AuthRepository authRepository;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = AppLocalizations.of(context)!.enterYourName);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.authRepository.completeProfile(fullName: name);
      if (!mounted) return;
      context.go('/customer');
    } on ApiException catch (e) {
      setState(() => _errorText = e.firstErrorFor('full_name') ?? e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.yourDetailsTitle),
        automaticallyImplyLeading: false,
      ),
      // See PhoneEntryScreen's build() comment — SingleChildScrollView
      // avoids a silent, unclickable overflow on short viewports.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: l10n.fullNameHint),
              onSubmitted: (_) => _submit(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.continueLabel),
            ),
          ],
        ),
      ),
    );
  }
}
