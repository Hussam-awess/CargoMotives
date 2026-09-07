import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/network/api_exception.dart';
import '../../l10n/generated/app_localizations.dart';
import 'data/auth_repository.dart';

/// Phone Entry (AppFlow §1): the first step for both roles after picking
/// "I'm a Customer" / "I'm a Transporter Company" on Welcome. Submitting
/// requests an OTP and hands off to the OTP screen — the phone number
/// itself isn't validated client-side beyond "non-empty"; the backend's
/// PhoneNumberNormalizer is the single source of truth for what counts as a
/// valid Tanzanian number, so errors surface from there rather than two
/// slightly-different validation rules drifting apart over time.
class PhoneEntryScreen extends StatefulWidget {
  PhoneEntryScreen({
    super.key,
    required this.role,
    AuthRepository? authRepository,
  }) : authRepository = authRepository ?? AuthRepository();

  final AccountRole role;
  final AuthRepository authRepository;

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorText = AppLocalizations.of(context)!.enterYourPhoneNumber);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.authRepository.requestOtp(
        phoneNumber: phone,
        role: widget.role,
      );
      if (!mounted) return;
      context.push(
        '/otp',
        extra: OtpScreenArgs(phoneNumber: phone, role: widget.role),
      );
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
      appBar: AppBar(title: Text(l10n.phoneEntryTitle)),
      // SingleChildScrollView, not just Padding+Column: on a short viewport
      // (a small phone, or a keyboard eating half the screen) an unscrolled
      // Column here silently overflows in release builds — no debug banner,
      // and Flutter's hit-testing decisively cannot register clicks past
      // the overflow. Found this the hard way testing at a real 254x245
      // logical-pixel viewport, where "Send code" looked fine but painted
      // outside the hit-testable layout, so tapping it did nothing at all.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.phoneEntrySubtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.phoneNumberHint,
                errorMaxLines: 2,
              ),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.sendCode),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data handed to the OTP screen — a typed class rather than a raw map so
/// the router's `extra` payload can't silently drift out of sync with what
/// OtpScreen expects.
class OtpScreenArgs {
  const OtpScreenArgs({required this.phoneNumber, required this.role});

  final String phoneNumber;
  final AccountRole role;
}
