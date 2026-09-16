import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/language_menu_button.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';

/// Forgot password — Transporter Company (phone-based, mirrors the SMS-OTP
/// pattern OtpScreen already uses for signup). A single screen with an
/// internal step, not two routed screens: this flow is short, reached only
/// from CompanyLoginScreen, and doesn't need its own place in the router.
///
/// Step 1 (enter phone, request a code) -> Step 2 (enter code + new
/// password) -> success. The backend's own response to step 1 is
/// deliberately generic about whether the number has an account
/// (AuthController::requestPasswordReset()) — this screen always advances
/// to step 2 regardless, for the same reason.
class CompanyForgotPasswordScreen extends StatefulWidget {
  CompanyForgotPasswordScreen({super.key, AuthRepository? repository}) : repository = repository ?? AuthRepository();

  final AuthRepository repository;

  @override
  State<CompanyForgotPasswordScreen> createState() => _CompanyForgotPasswordScreenState();
}

enum _Step { requestCode, resetPassword, success }

class _CompanyForgotPasswordScreenState extends State<CompanyForgotPasswordScreen> {
  static const _resendCooldownSeconds = 60;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _Step _step = _Step.requestCode;
  bool _isSubmitting = false;
  String? _errorText;
  Timer? _cooldownTimer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _secondsRemaining = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _requestCode() async {
    final l10n = AppLocalizations.of(context)!;
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorText = l10n.enterYourPhoneNumber);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.repository.requestPasswordReset(phoneNumber: phone);
      if (!mounted) return;
      _startCooldown(_resendCooldownSeconds);
      setState(() => _step = _Step.resetPassword);
    } on ApiException catch (e) {
      if (!mounted) return;
      final secondsRemaining = e.body?['seconds_remaining'];
      if (secondsRemaining is int) _startCooldown(secondsRemaining);
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    final password = _passwordController.text;

    if (code.length != 6) {
      setState(() => _errorText = l10n.enterSixDigitCode);
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = l10n.enterAPassword);
      return;
    }
    if (password != _confirmPasswordController.text) {
      setState(() => _errorText = l10n.passwordsDoNotMatch);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.repository.confirmPasswordReset(phoneNumber: _phoneController.text.trim(), code: code, password: password);
      if (!mounted) return;
      setState(() => _step = _Step.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.firstErrorFor('code') ?? e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle), actions: const [LanguageMenuButton()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: switch (_step) {
          _Step.requestCode => _RequestCodeStep(
            phoneController: _phoneController,
            isSubmitting: _isSubmitting,
            errorText: _errorText,
            onSubmit: _requestCode,
          ),
          _Step.resetPassword => _ResetPasswordStep(
            codeController: _codeController,
            passwordController: _passwordController,
            confirmPasswordController: _confirmPasswordController,
            isSubmitting: _isSubmitting,
            errorText: _errorText,
            secondsRemaining: _secondsRemaining,
            onSubmit: _resetPassword,
            onResend: _requestCode,
            onUseADifferentNumber: () => setState(() {
              _step = _Step.requestCode;
              _errorText = null;
              _codeController.clear();
            }),
          ),
          _Step.success => _SuccessStep(onBackToLogin: () => Navigator.of(context).pop()),
        },
      ),
    );
  }
}

class _RequestCodeStep extends StatelessWidget {
  const _RequestCodeStep({required this.phoneController, required this.isSubmitting, required this.errorText, required this.onSubmit});

  final TextEditingController phoneController;
  final bool isSubmitting;
  final String? errorText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.forgotPasswordInstructionsPhone, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        TextField(
          controller: phoneController,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(hintText: l10n.phoneNumberHint),
          onSubmitted: (_) => onSubmit(),
        ),
        if (errorText != null) ...[const SizedBox(height: 8), Text(errorText!, style: const TextStyle(color: Colors.red))],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l10n.sendResetCodeLabel),
        ),
      ],
    );
  }
}

class _ResetPasswordStep extends StatelessWidget {
  const _ResetPasswordStep({
    required this.codeController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isSubmitting,
    required this.errorText,
    required this.secondsRemaining,
    required this.onSubmit,
    required this.onResend,
    required this.onUseADifferentNumber,
  });

  final TextEditingController codeController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isSubmitting;
  final String? errorText;
  final int secondsRemaining;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  final VoidCallback onUseADifferentNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(counterText: ''),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(hintText: l10n.newPasswordHint, helperText: l10n.passwordHelperText),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(hintText: l10n.confirmPasswordHint),
          onSubmitted: (_) => onSubmit(),
        ),
        if (errorText != null) ...[const SizedBox(height: 8), Text(errorText!, style: const TextStyle(color: Colors.red))],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l10n.resetPasswordButtonLabel),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: (secondsRemaining > 0 || isSubmitting) ? null : onResend,
          child: Text(secondsRemaining > 0 ? l10n.resendCodeIn(secondsRemaining) : l10n.resendCode),
        ),
        Center(
          child: TextButton(onPressed: onUseADifferentNumber, child: Text(l10n.useADifferentNumberLabel)),
        ),
      ],
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.onBackToLogin});

  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle, size: 56),
        const SizedBox(height: 16),
        Text(l10n.passwordResetSuccessMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onBackToLogin, child: Text(l10n.backToLoginLabel)),
      ],
    );
  }
}
