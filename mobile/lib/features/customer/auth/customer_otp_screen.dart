import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/localization/language_menu_button.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'data/customer_auth_repository.dart';

/// Email-OTP entry for Customer sign-up (Phase 11) — the email-shaped
/// counterpart to OtpScreen (phone/SMS, Transporter Company). Holds onto
/// the full CustomerRegistration (not just the email) so "resend" can
/// call register() again with the exact same data — the backend's emailed
/// code is only ever issued as a side effect of a registration attempt,
/// there's no separate lightweight "resend" endpoint.
class CustomerOtpScreen extends StatefulWidget {
  CustomerOtpScreen({
    super.key,
    required this.registration,
    CustomerAuthRepository? repository,
    SessionStore? sessionStore,
  }) : repository = repository ?? CustomerAuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final CustomerRegistration registration;
  final CustomerAuthRepository repository;
  final SessionStore sessionStore;

  @override
  State<CustomerOtpScreen> createState() => _CustomerOtpScreenState();
}

class _CustomerOtpScreenState extends State<CustomerOtpScreen> {
  static const _resendCooldownSeconds = 60;

  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;
  Timer? _cooldownTimer;
  int _secondsRemaining = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown(_resendCooldownSeconds);
  }

  @override
  void dispose() {
    _codeController.dispose();
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

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      await widget.repository.register(widget.registration);
      _startCooldown(_resendCooldownSeconds);
    } on ApiException catch (e) {
      if (!mounted) return;
      final secondsRemaining = e.body?['seconds_remaining'];
      if (secondsRemaining is int) {
        _startCooldown(secondsRemaining);
      }
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorText = AppLocalizations.of(context)!.enterSixDigitCode);
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final token = await widget.repository.verifyRegistration(
        email: widget.registration.email,
        code: code,
      );
      await widget.sessionStore.save(token: token, role: AccountRole.customer);
      if (!mounted) return;
      context.go('/customer');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.firstErrorFor('code') ?? e.message);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verifyEmailTitle),
        actions: const [LanguageMenuButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.verifyEmailSubtitle(widget.registration.email),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (_) => _verify(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verify,
              child: _isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.verify),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: (_secondsRemaining > 0 || _isResending) ? null : _resend,
              child: Text(
                _secondsRemaining > 0 ? l10n.resendCodeIn(_secondsRemaining) : l10n.resendCode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
