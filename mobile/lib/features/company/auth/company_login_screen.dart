import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/localization/language_menu_button.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/validation/phone_input.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/password_field.dart';
import '../../auth/data/auth_repository.dart';
import 'company_forgot_password_screen.dart';

/// Transporter Company login (design-import restyle): phone + password —
/// mirrors CustomerLoginScreen exactly. OTP is a one-time signup
/// verification step (PhoneEntryScreen/OtpScreen), never asked again here.
class CompanyLoginScreen extends StatefulWidget {
  CompanyLoginScreen({
    super.key,
    AuthRepository? repository,
    SessionStore? sessionStore,
  }) : repository = repository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final AuthRepository repository;
  final SessionStore sessionStore;

  @override
  State<CompanyLoginScreen> createState() => _CompanyLoginScreenState();
}

class _CompanyLoginScreenState extends State<CompanyLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty) {
      setState(() => _errorText = l10n.enterYourPhoneNumber);
      return;
    }
    if (!isValidTanzanianPhone(phone)) {
      setState(() => _errorText = l10n.invalidPhoneNumberFormat);
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = l10n.enterAPassword);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final token = await widget.repository.login(
        phoneNumber: phone,
        password: password,
      );
      await widget.sessionStore.save(
        token: token,
        role: AccountRole.transporterCompany,
      );
      if (!mounted) return;
      context.go('/company');
    } on ApiException catch (e) {
      setState(() => _errorText = e.firstErrorFor('phone_number') ?? e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.companyLoginTitle),
        actions: const [LanguageMenuButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: tanzanianPhoneInputFormatters,
              decoration: InputDecoration(hintText: l10n.phoneNumberHint),
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _passwordController,
              hintText: l10n.passwordHint,
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompanyForgotPasswordScreen(
                      repository: widget.repository,
                    ),
                  ),
                ),
                child: Text(l10n.forgotPasswordLabel),
              ),
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
                  : Text(l10n.logIn),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.push(
                  '/phone-entry',
                  extra: AccountRole.transporterCompany,
                ),
                child: Text('${l10n.dontHaveAnAccount} ${l10n.signUp}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
