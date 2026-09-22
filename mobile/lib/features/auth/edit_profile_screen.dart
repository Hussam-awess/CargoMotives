import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validation/phone_input.dart';
import 'data/auth_repository.dart';

enum ProfileCredential { email, phone }

/// Real profile editing (Phase 10.16, extended later) — every field
/// collected at signup is editable here, for both roles:
///  - A personal profile photo (avatar) and full name apply immediately.
///  - The account's login credential (Customer's email, Transporter
///    Company's phone) goes through a send-code-then-confirm step first,
///    since changing it without verification would let someone lock the
///    real owner out just by typing a new value into an unlocked device.
///  - The *other* contact field (Customer's phone, Company's email) isn't
///    a login credential, so it applies immediately, same as full name.
///  - A Customer's optional business identity (company name + logo, shown
///    to companies bidding on their jobs) is editable here too. A
///    Transporter Company's own business identity is a heavier,
///    Admin-reviewed resubmission (CompanyVerificationScreen) — deliberately
///    not duplicated here.
class EditProfileScreen extends StatefulWidget {
  EditProfileScreen({super.key, required this.profile, required this.credential, AuthRepository? authRepository})
    : authRepository = authRepository ?? AuthRepository();

  final UserProfile profile;
  final ProfileCredential credential;
  final AuthRepository authRepository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _CredentialStep { idle, enteringValue, enteringCode }

class _EditProfileScreenState extends State<EditProfileScreen> {
  late UserProfile _profile;
  late final _nameController = TextEditingController(text: _profile.fullName);
  late final _secondaryController = TextEditingController(
    text: _currentSecondaryValue == '—'
        ? ''
        : (widget.credential == ProfileCredential.email ? toLocalPhoneDisplay(_currentSecondaryValue) : _currentSecondaryValue),
  );
  late final _companyNameController = TextEditingController(text: _profile.companyName ?? '');
  final _newValueController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isSavingName = false;
  String? _nameError;

  bool _isUploadingAvatar = false;

  bool _isSavingSecondary = false;
  String? _secondaryError;

  PlatformFile? _logo;
  bool _isSavingBusiness = false;
  String? _businessError;

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
    _secondaryController.dispose();
    _companyNameController.dispose();
    _newValueController.dispose();
    _currentPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// A Customer's login credential is email (Transporter Company's is
  /// phone) — the only two roles this screen serves, so this also tells us
  /// whether the optional business-identity section applies.
  bool get _isCustomer => widget.credential == ProfileCredential.email;

  String get _credentialLabel => widget.credential == ProfileCredential.email ? 'Email' : 'Phone number';
  String get _currentCredentialValue => (widget.credential == ProfileCredential.email ? _profile.email : _profile.phoneNumber) ?? '—';

  String get _secondaryLabel => widget.credential == ProfileCredential.email ? 'Phone number' : 'Email';
  String get _currentSecondaryValue => (widget.credential == ProfileCredential.email ? _profile.phoneNumber : _profile.email) ?? '—';

  Future<void> _pickAvatar() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.singleOrNull;
    if (file == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final updated = await widget.authRepository.updateAvatar(file);
      if (!mounted) return;
      setState(() => _profile = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

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

  Future<void> _saveSecondary() async {
    final value = _secondaryController.text.trim();
    if (value.isEmpty) {
      setState(() => _secondaryError = 'Enter your ${_secondaryLabel.toLowerCase()}.');
      return;
    }
    if (widget.credential == ProfileCredential.email && !isValidTanzanianPhone(value)) {
      setState(() => _secondaryError = 'Enter a valid 10-digit phone number starting with 0 (e.g. 0712345678).');
      return;
    }

    setState(() {
      _isSavingSecondary = true;
      _secondaryError = null;
    });

    try {
      final updated = widget.credential == ProfileCredential.email
          ? await widget.authRepository.updatePhone(value)
          : await widget.authRepository.updateEmail(value);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_secondaryLabel updated.')));
    } on ApiException catch (e) {
      final field = widget.credential == ProfileCredential.email ? 'phone_number' : 'email';
      setState(() => _secondaryError = e.firstErrorFor(field) ?? e.message);
    } finally {
      if (mounted) setState(() => _isSavingSecondary = false);
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.singleOrNull;
    if (file != null) setState(() => _logo = file);
  }

  Future<void> _saveBusinessIdentity() async {
    setState(() {
      _isSavingBusiness = true;
      _businessError = null;
    });

    try {
      final name = _companyNameController.text.trim();
      final updated = await widget.authRepository.updateBusinessIdentity(companyName: name.isEmpty ? null : name, logo: _logo);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _logo = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business details updated.')));
    } on ApiException catch (e) {
      setState(() => _businessError = e.firstErrorFor('company_name') ?? e.firstErrorFor('logo') ?? e.message);
    } finally {
      if (mounted) setState(() => _isSavingBusiness = false);
    }
  }

  Future<void> _sendCode() async {
    final newValue = _newValueController.text.trim();
    final currentPassword = _currentPasswordController.text;

    if (newValue.isEmpty) {
      setState(() => _credentialError = 'Enter a new ${_credentialLabel.toLowerCase()}.');
      return;
    }
    if (widget.credential == ProfileCredential.phone && !isValidTanzanianPhone(newValue)) {
      setState(() => _credentialError = 'Enter a valid 10-digit phone number starting with 0 (e.g. 0712345678).');
      return;
    }
    if (currentPassword.isEmpty) {
      setState(() => _credentialError = 'Enter your current password to confirm this change.');
      return;
    }

    setState(() {
      _isCredentialBusy = true;
      _credentialError = null;
    });

    try {
      if (widget.credential == ProfileCredential.email) {
        await widget.authRepository.requestEmailChange(newValue, currentPassword: currentPassword);
      } else {
        await widget.authRepository.requestPhoneChange(newValue, currentPassword: currentPassword);
      }
      if (!mounted) return;
      setState(() {
        _pendingNewValue = newValue;
        _credentialStep = _CredentialStep.enteringCode;
        _currentPasswordController.clear();
      });
    } on ApiException catch (e) {
      final field = widget.credential == ProfileCredential.email ? 'new_email' : 'new_phone';
      setState(() => _credentialError = e.firstErrorFor(field) ?? e.firstErrorFor('current_password') ?? e.message);
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
            Center(child: _buildAvatar()),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            Text(
              'Full name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('nameField'),
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
            Text(
              _credentialLabel,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLabel),
            ),
            const SizedBox(height: 8),
            _buildCredentialSection(),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            Text(
              _secondaryLabel,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('secondaryField'),
              controller: _secondaryController,
              decoration: InputDecoration(errorText: _secondaryError),
              keyboardType: widget.credential == ProfileCredential.email ? TextInputType.phone : TextInputType.emailAddress,
              inputFormatters: widget.credential == ProfileCredential.email ? tanzanianPhoneInputFormatters : null,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _isSavingSecondary ? null : _saveSecondary,
                child: _isSavingSecondary
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Save ${_secondaryLabel.toLowerCase()}'),
              ),
            ),
            if (_isCustomer) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 20),
              Text(
                'Business details (optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLabel),
              ),
              const SizedBox(height: 4),
              Text('Shown to transporters bidding on your jobs.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                key: const Key('companyNameField'),
                controller: _companyNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Company name'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.image_outlined),
                label: Text(_logo?.name ?? (_profile.companyLogoUrl != null ? 'Change logo' : 'Upload logo (optional)')),
              ),
              if (_businessError != null) ...[
                const SizedBox(height: 6),
                Text(_businessError!, style: TextStyle(color: AppColors.statusError, fontSize: 12.5)),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _isSavingBusiness ? null : _saveBusinessIdentity,
                  child: _isSavingBusiness
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save business details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.infoTint,
          backgroundImage: _profile.avatarUrl != null ? NetworkImage(_profile.avatarUrl!) : null,
          child: _profile.avatarUrl == null ? Icon(Icons.person_outline, size: 40, color: AppColors.ctaBlue) : null,
        ),
        if (_isUploadingAvatar)
          const Positioned.fill(
            child: CircleAvatar(
              backgroundColor: Colors.black38,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: InkWell(
            onTap: _isUploadingAvatar ? null : _pickAvatar,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.ctaBlue,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
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
              key: const Key('credentialNewValueField'),
              controller: _newValueController,
              decoration: InputDecoration(labelText: 'New $_credentialLabel'.toLowerCase(), errorText: _credentialError),
              keyboardType: widget.credential == ProfileCredential.email ? TextInputType.emailAddress : TextInputType.phone,
              inputFormatters: widget.credential == ProfileCredential.phone ? tanzanianPhoneInputFormatters : null,
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('credentialCurrentPasswordField'),
              controller: _currentPasswordController,
              decoration: const InputDecoration(labelText: 'Current password'),
              obscureText: true,
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
            Text('We sent a code to $_pendingNewValue.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              key: const Key('credentialCodeField'),
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
