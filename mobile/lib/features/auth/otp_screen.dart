import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/localization/language_menu_button.dart';
import '../../core/network/api_exception.dart';
import '../../l10n/generated/app_localizations.dart';
import 'data/auth_repository.dart';
import 'phone_entry_screen.dart';

/// OTP entry for Transporter Company (AppFlow §1; Customer moved to
/// email+password in Phase 11 — see CustomerOtpScreen). Also collects
/// full_name + email here now (Phase 11's "Step 1 — Account
/// authentication" groups these with phone+OTP, rather than deferring
/// them the way Customer's old profile-setup step used to) — both are
/// submitted together with the code in one verifyOtp() call.
///
/// Mirrors the backend's OtpService rules so the UI doesn't surprise the
/// user: a 60s resend cooldown (config/otp.php on the backend — kept in
/// sync here as a starting value, then corrected from the server's actual
/// `seconds_remaining` if a resend is attempted early).
class OtpScreen extends StatefulWidget {
  OtpScreen({
    super.key,
    required this.args,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
  }) : authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final OtpScreenArgs args;
  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _resendCooldownSeconds = 60;

  final _codeController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

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
    _fullNameController.dispose();
    _emailController.dispose();
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
      await widget.authRepository.requestOtp(
        phoneNumber: widget.args.phoneNumber,
        role: widget.args.role,
      );
      _startCooldown(_resendCooldownSeconds);
    } on ApiException catch (e) {
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
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();

    if (code.length != 6) {
      setState(() => _errorText = l10n.enterSixDigitCode);
      return;
    }
    if (fullName.isEmpty) {
      setState(() => _errorText = l10n.enterYourName);
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorText = l10n.enterYourEmail);
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final result = await widget.authRepository.verifyOtp(
        phoneNumber: widget.args.phoneNumber,
        role: widget.args.role,
        code: code,
        fullName: fullName,
        email: email,
      );

      await widget.sessionStore.save(
        token: result.token,
        role: widget.args.role,
      );
      if (!mounted) return;

      // '/company' (CompanyHomeGate) decides internally whether that's the
      // verification form, a pending-review screen, or Company Home.
      context.go('/company');
    } on ApiException catch (e) {
      setState(() {
        _errorText = e.firstErrorFor('code') ?? e.firstErrorFor('email') ?? e.message;
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.otpTitle), actions: const [LanguageMenuButton()]),
      // See PhoneEntryScreen's build() comment — SingleChildScrollView
      // avoids a silent, unclickable overflow on short viewports.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.otpSubtitle(widget.args.phoneNumber),
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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: l10n.fullNameHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: l10n.emailHint),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.verify),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: (_secondsRemaining > 0 || _isResending)
                  ? null
                  : _resend,
              child: Text(
                _secondsRemaining > 0
                    ? l10n.resendCodeIn(_secondsRemaining)
                    : l10n.resendCode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
