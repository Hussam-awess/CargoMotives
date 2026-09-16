import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/localization/language_menu_button.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'customer_forgot_password_screen.dart';
import 'data/customer_auth_repository.dart';

/// Customer login (Phase 11): email + password only — the emailed code
/// from CustomerRegisterScreen/CustomerOtpScreen is a one-time signup
/// verification step, never asked again here.
class CustomerLoginScreen extends StatefulWidget {
  CustomerLoginScreen({super.key, CustomerAuthRepository? repository, SessionStore? sessionStore})
    : repository = repository ?? CustomerAuthRepository(),
      sessionStore = sessionStore ?? SessionStore();

  final CustomerAuthRepository repository;
  final SessionStore sessionStore;

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

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
      final token = await widget.repository.login(email: email, password: password);
      await widget.sessionStore.save(token: token, role: AccountRole.customer);
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
      appBar: AppBar(title: Text(l10n.customerLoginTitle), actions: const [LanguageMenuButton()]),
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
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(hintText: l10n.passwordHint),
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => CustomerForgotPasswordScreen(repository: widget.repository))),
                child: Text(l10n.forgotPasswordLabel),
              ),
            ),
            if (_errorText != null) ...[const SizedBox(height: 8), Text(_errorText!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
