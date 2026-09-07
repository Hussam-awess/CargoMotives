import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_menu_button.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'data/customer_auth_repository.dart';

/// Customer sign-up (Phase 11 product decision): full name, email, phone
/// number, company name + logo (optional — shown to companies bidding on
/// this customer's jobs, see JobResource), and a password. Submitting
/// requests an emailed verification code and hands off to
/// CustomerOtpScreen, mirroring the shape of the Transporter Company's
/// phone-entry -> OTP flow (PhoneEntryScreen/OtpScreen) even though the
/// channel and fields differ.
class CustomerRegisterScreen extends StatefulWidget {
  CustomerRegisterScreen({super.key, CustomerAuthRepository? repository})
    : repository = repository ?? CustomerAuthRepository();

  final CustomerAuthRepository repository;

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  PlatformFile? _logo;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    for (final c in [
      _fullNameController,
      _emailController,
      _phoneController,
      _companyNameController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.singleOrNull;
    if (file != null) setState(() => _logo = file);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty) {
      setState(() => _errorText = l10n.enterYourName);
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorText = l10n.enterYourEmail);
      return;
    }
    if (phone.isEmpty) {
      setState(() => _errorText = l10n.enterYourPhoneNumber);
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = l10n.enterAPassword);
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorText = l10n.passwordsDoNotMatch);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final companyName = _companyNameController.text.trim();
    final registration = CustomerRegistration(
      fullName: fullName,
      email: email,
      phoneNumber: phone,
      password: password,
      passwordConfirmation: confirmPassword,
      companyName: companyName.isEmpty ? null : companyName,
      logo: _logo,
    );

    try {
      await widget.repository.register(registration);
      if (!mounted) return;
      context.push('/customer-otp', extra: registration);
    } on ApiException catch (e) {
      setState(() {
        _errorText =
            e.firstErrorFor('email') ??
            e.firstErrorFor('phone_number') ??
            e.firstErrorFor('password') ??
            e.message;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customerSignUpTitle),
        actions: const [LanguageMenuButton()],
      ),
      // SingleChildScrollView — see PhoneEntryScreen's build() comment for
      // why: an unscrolled Column silently overflows on short viewports.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _fullNameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: l10n.fullNameHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: l10n.emailHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(hintText: l10n.phoneNumberHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: l10n.companyNameOptionalHint),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.image_outlined),
              label: Text(_logo?.name ?? l10n.uploadLogoOptional),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(hintText: l10n.passwordHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(hintText: l10n.confirmPasswordHint),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.createAccount),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go('/customer-login'),
                child: Text('${l10n.alreadyHaveAnAccount} ${l10n.logIn}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
