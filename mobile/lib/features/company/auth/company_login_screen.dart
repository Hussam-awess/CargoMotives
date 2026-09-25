import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/local/local_prefs.dart';
import '../../../core/localization/language_menu_button.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/validation/phone_input.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/password_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/two_factor_repository.dart';
import '../../auth/two_factor_code_screen.dart';
import 'company_forgot_password_screen.dart';

/// Transporter Company login (design-import restyle): phone + password —
/// mirrors CustomerLoginScreen exactly. OTP is a one-time signup
/// verification step (PhoneEntryScreen/OtpScreen), never asked again here.
class CompanyLoginScreen extends StatefulWidget {
  CompanyLoginScreen({
    super.key,
    AuthRepository? repository,
    SessionStore? sessionStore,
    TwoFactorRepository? twoFactorRepository,
    this.prefs = const LocalPrefs(),
  }) : repository = repository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore(),
       twoFactorRepository = twoFactorRepository ?? TwoFactorRepository();

  final AuthRepository repository;
  final SessionStore sessionStore;
  final TwoFactorRepository twoFactorRepository;
  final LocalPrefs prefs;

  @override
  State<CompanyLoginScreen> createState() => _CompanyLoginScreenState();
}

class _CompanyLoginScreenState extends State<CompanyLoginScreen> {
  // Remembers only the phone number, never the password — see
  // CustomerLoginScreen's identical fields for why (a plaintext-password
  // store would be a real security hole, and staying logged in between
  // app launches is already SessionStore's job via the persisted token).
  static const _rememberMeKey = 'company_login_remember_me';
  static const _rememberedPhoneKey = 'company_login_remembered_phone';

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _rememberMe = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadRememberedPhone();
  }

  Future<void> _loadRememberedPhone() async {
    final remembered = await widget.prefs.getBool(
      _rememberMeKey,
      defaultValue: false,
    );
    if (!remembered) return;
    final phone = await widget.prefs.getString(_rememberedPhoneKey);
    if (!mounted || phone == null) return;
    setState(() {
      _rememberMe = true;
      _phoneController.text = phone;
    });
  }

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
      String? token;
      try {
        token = await widget.repository.login(phoneNumber: phone, password: password);
      } on TwoFactorRequired catch (challenge) {
        if (!mounted) return;
        token = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => TwoFactorCodeScreen(challenge: challenge, repository: widget.twoFactorRepository),
          ),
        );
        if (token == null) return;
      }
      await widget.sessionStore.save(
        token: token,
        role: AccountRole.transporterCompany,
      );
      await widget.prefs.setBool(_rememberMeKey, _rememberMe);
      if (_rememberMe) {
        await widget.prefs.setString(_rememberedPhoneKey, phone);
      } else {
        await widget.prefs.remove(_rememberedPhoneKey);
      }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                      ),
                      Text(l10n.rememberMe),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CompanyForgotPasswordScreen(
                        repository: widget.repository,
                      ),
                    ),
                  ),
                  child: Text(l10n.forgotPasswordLabel),
                ),
              ],
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
