import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../l10n/generated/app_localizations.dart';
import 'data/two_factor_repository.dart';

/// The second login step for an account with two-factor authentication on
/// — shared by both roles. Pops with the new session token on success, or
/// null if the user backs out (the login screen then simply stays put).
class TwoFactorCodeScreen extends StatefulWidget {
  TwoFactorCodeScreen({super.key, required this.challenge, TwoFactorRepository? repository})
    : repository = repository ?? TwoFactorRepository();

  final TwoFactorRequired challenge;
  final TwoFactorRepository repository;

  @override
  State<TwoFactorCodeScreen> createState() => _TwoFactorCodeScreenState();
}

class _TwoFactorCodeScreenState extends State<TwoFactorCodeScreen> {
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
      if (!mounted) return timer.cancel();
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorText = l10n.enterSixDigitCode);
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final token = await widget.repository.verify(challengeToken: widget.challenge.challengeToken, code: code);
      if (mounted) Navigator.of(context).pop(token);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.firstErrorFor('code') ?? e.firstErrorFor('challenge_token') ?? e.message);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      await widget.repository.resend(challengeToken: widget.challenge.challengeToken);
      if (!mounted) return;
      _startCooldown(_resendCooldownSeconds);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.codeResentMessage)));
    } on ApiException catch (e) {
      if (!mounted) return;
      final secondsRemaining = e.body?['seconds_remaining'];
      if (secondsRemaining is int) _startCooldown(secondsRemaining);
      setState(() => _errorText = e.firstErrorFor('challenge_token') ?? e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sentTo = widget.challenge.channel == 'email'
        ? l10n.twoFactorCodeSentEmail(widget.challenge.destination)
        : l10n.twoFactorCodeSentSms(widget.challenge.destination);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.twoFactorCodeTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(sentTo, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextField(
              key: const Key('twoFactorCodeField'),
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(counterText: '', labelText: l10n.twoFactorCodeTitle),
              onSubmitted: (_) => _verify(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
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
              child: Text(_secondsRemaining > 0 ? l10n.resendCodeIn(_secondsRemaining) : l10n.resendCode),
            ),
          ],
        ),
      ),
    );
  }
}
