import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'data/auth_repository.dart';

enum ProfileCredential { email, phone }

/// Real profile editing (Phase 10.16) — the name always saves immediately
/// (it isn't a login credential), but the account's login credential
/// (Customer's email, Transporter Company's phone) goes through a
/// send-code-then-confirm step first, since changing it without
/// verification would let someone lock the real owner out just by typing
/// a new value into an unlocked device.
class EditProfileScreen extends StatefulWidget {
  EditProfileScreen({super.key, required this.profile, required this.credential, this.showName = true, AuthRepository? authRepository})
    : authRepository = authRepository ?? AuthRepository();

  final UserProfile profile;
  final ProfileCredential credential;

  /// Company's User.full_name isn't a real, displayed identity (the
  /// company's own name lives on TransporterCompany) — its Edit Profile
  /// screen skips this section entirely rather than editing a field
  /// nothing shows.
  final bool showName;

  final AuthRepository authRepository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _CredentialStep { idle, enteringValue, enteringCode }

class _EditProfileScreenState extends State<EditProfileScreen> {
  late UserProfile _profile;
  late final _nameController = TextEditingController(text: _profile.fullName);
  final _newValueController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isSavingName = false;
  String? _nameError;

  _CredentialStep _credentialStep = _CredentialStep.idle;
  bool _isCredentialBusy = false;
  String? _credentialError;
  String? _pendingNewValue;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newValueController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _credentialLabel => widget.credential == ProfileCredential.email ? 'Email' : 'Phone number';
  String get _currentCredentialValue => (widget.credential == ProfileCredential.email ? _profile.email : _profile.phoneNumber) ?? '—';

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Full name is required.');
      return;
    }

    setState(() {
      _isSavingName = true;
      _nameError = null;
    });

    try {
      final updated = await widget.authRepository.updateFullName(name);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated.')));
    } on ApiException catch (e) {
      setState(() => _nameError = e.firstErrorFor('full_name') ?? e.message);
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _sendCode() async {
    final newValue = _newValueController.text.trim();
    if (newValue.isEmpty) {
      setState(() => _credentialError = 'Enter a new ${_credentialLabel.toLowerCase()}.');
      return;
    }

    setState(() {
      _isCredentialBusy = true;
      _credentialError = null;
    });

    try {
      if (widget.credential == ProfileCredential.email) {
        await widget.authRepository.requestEmailChange(newValue);
      } else {
        await widget.authRepository.requestPhoneChange(newValue);
      }
      if (!mounted) return;
      setState(() {
        _pendingNewValue = newValue;
        _credentialStep = _CredentialStep.enteringCode;
      });
    } on ApiException catch (e) {
      final field = widget.credential == ProfileCredential.email ? 'new_email' : 'new_phone';
      setState(() => _credentialError = e.firstErrorFor(field) ?? e.message);
    } finally {
      if (mounted) setState(() => _isCredentialBusy = false);
    }
  }

  Future<void> _confirmCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _credentialError = 'Enter the code we sent.');
      return;
    }

    setState(() {
      _isCredentialBusy = true;
      _credentialError = null;
    });

    try {
      final updated = widget.credential == ProfileCredential.email
          ? await widget.authRepository.confirmEmailChange(newEmail: _pendingNewValue!, code: code)
          : await widget.authRepository.confirmPhoneChange(newPhone: _pendingNewValue!, code: code);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _credentialStep = _CredentialStep.idle;
        _newValueController.clear();
        _codeController.clear();
        _pendingNewValue = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_credentialLabel updated.')));
    } on ApiException catch (e) {
      setState(() => _credentialError = e.firstErrorFor('code') ?? e.message);
    } finally {
      if (mounted) setState(() => _isCredentialBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showName) ...[
              const Text(
                'Full name',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(errorText: _nameError),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _isSavingName ? null : _saveName,
                  child: _isSavingName
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save name'),
                ),
              ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 20),
            ],
            Text(
              _credentialLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLabel),
            ),
            const SizedBox(height: 8),
            _buildCredentialSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialSection() {
    switch (_credentialStep) {
      case _CredentialStep.idle:
        return Row(
          children: [
            Expanded(child: Text(_currentCredentialValue, style: const TextStyle(fontSize: 15))),
            TextButton(onPressed: () => setState(() => _credentialStep = _CredentialStep.enteringValue), child: const Text('Change')),
          ],
        );
      case _CredentialStep.enteringValue:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _newValueController,
              decoration: InputDecoration(labelText: 'New $_credentialLabel'.toLowerCase(), errorText: _credentialError),
              keyboardType: widget.credential == ProfileCredential.email ? TextInputType.emailAddress : TextInputType.phone,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: _isCredentialBusy ? null : () => setState(() => _credentialStep = _CredentialStep.idle),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _isCredentialBusy ? null : _sendCode,
                  child: _isCredentialBusy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send code'),
                ),
              ],
            ),
          ],
        );
      case _CredentialStep.enteringCode:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We sent a code to $_pendingNewValue.', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(labelText: 'Confirmation code', errorText: _credentialError),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: _isCredentialBusy
                      ? null
                      : () => setState(() {
                          _credentialStep = _CredentialStep.idle;
                          _pendingNewValue = null;
                        }),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _isCredentialBusy ? null : _confirmCode,
                  child: _isCredentialBusy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm'),
                ),
              ],
            ),
          ],
        );
    }
  }
}
