import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/local/local_prefs.dart';
import '../../../core/localization/language_menu_button.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/password_field.dart';
import '../../auth/data/two_factor_repository.dart';
import '../../auth/two_factor_code_screen.dart';
import 'customer_forgot_password_screen.dart';
import 'data/customer_auth_repository.dart';

/// Customer login (Phase 11): email + password only — the emailed code
/// from CustomerRegisterScreen/CustomerOtpScreen is a one-time signup
/// verification step, never asked again here.
class CustomerLoginScreen extends StatefulWidget {
  CustomerLoginScreen({
    super.key,
    CustomerAuthRepository? repository,
    SessionStore? sessionStore,
    TwoFactorRepository? twoFactorRepository,
    this.prefs = const LocalPrefs(),
  }) : repository = repository ?? CustomerAuthRepository(),
       sessionStore = sessionStore ?? SessionStore(),
       twoFactorRepository = twoFactorRepository ?? TwoFactorRepository();

  final CustomerAuthRepository repository;
  final SessionStore sessionStore;
  final TwoFactorRepository twoFactorRepository;
  final LocalPrefs prefs;

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  // Remembers only the email, never the password — a plaintext-password
  // store would be a real security hole. Actually staying logged in
  // between app launches is already SessionStore's job (the persisted
  // auth token); this is purely about not retyping the email on a fresh
  // login (after a logout, a reinstall, etc.).
  static const _rememberMeKey = 'customer_login_remember_me';
  static const _rememberedEmailKey = 'customer_login_remembered_email';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _rememberMe = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final remembered = await widget.prefs.getBool(
      _rememberMeKey,
      defaultValue: false,
    );
    if (!remembered) return;
    final email = await widget.prefs.getString(_rememberedEmailKey);
    if (!mounted || email == null) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = email;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorText = l10n.enterYourEmail);
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
        token = await widget.repository.login(email: email, password: password);
      } on TwoFactorRequired catch (challenge) {
        if (!mounted) return;
        token = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => TwoFactorCodeScreen(challenge: challenge, repository: widget.twoFactorRepository),
          ),
        );
        if (token == null) return;
      }
      await widget.sessionStore.save(token: token, role: AccountRole.customer);
      await widget.prefs.setBool(_rememberMeKey, _rememberMe);
      if (_rememberMe) {
        await widget.prefs.setString(_rememberedEmailKey, email);
      } else {
        await widget.prefs.remove(_rememberedEmailKey);
      }
      if (!mounted) return;
      context.go('/customer');
    } on ApiException catch (e) {
      setState(() => _errorText = e.firstErrorFor('email') ?? e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customerLoginTitle),
        actions: const [LanguageMenuButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: l10n.emailHint),
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
                      builder: (_) => CustomerForgotPasswordScreen(
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
                onPressed: () => context.push('/customer-register'),
                child: Text('${l10n.dontHaveAnAccount} ${l10n.signUp}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
