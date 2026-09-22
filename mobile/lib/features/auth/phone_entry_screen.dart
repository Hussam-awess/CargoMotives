import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/localization/language_menu_button.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validation/phone_input.dart';
import '../../core/widgets/terms_agreement_checkbox.dart';
import '../../l10n/generated/app_localizations.dart';
import 'data/auth_repository.dart';

/// Transporter Company sign-up · Step 1 of 3 — Account (AppFlow §1;
/// design-import restyle). Collects phone, full name, email and a
/// password together (matching the mockup's "Step 1 — Account" screen),
/// not just the phone number — full_name/email/password used to be
/// collected on the OTP screen itself; they moved here so that screen can
/// be a plain code entry, matching the mockup. The account itself is still
/// only created once the OTP verifies (AuthController's pending-cache
/// pattern) — this screen only requests the code.
class PhoneEntryScreen extends StatefulWidget {
  PhoneEntryScreen({super.key, required this.role, AuthRepository? authRepository}) : authRepository = authRepository ?? AuthRepository();

  final AccountRole role;
  final AuthRepository authRepository;

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _acceptedTerms = false;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final phone = _phoneController.text.trim();
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty) {
      setState(() => _errorText = l10n.enterYourPhoneNumber);
      return;
    }
    if (!isValidTanzanianPhone(phone)) {
      setState(() => _errorText = l10n.invalidPhoneNumberFormat);
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
    if (password.isEmpty) {
      setState(() => _errorText = l10n.enterAPassword);
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _errorText = l10n.pleaseAcceptTerms);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.authRepository.requestOtp(phoneNumber: phone, role: widget.role, fullName: fullName, email: email, password: password);
      if (!mounted) return;
      context.push(
        '/otp',
        extra: OtpScreenArgs(phoneNumber: phone, role: widget.role, fullName: fullName, email: email, password: password),
      );
    } on ApiException catch (e) {
      setState(() {
        _errorText = e.firstErrorFor('phone_number') ?? e.firstErrorFor('email') ?? e.firstErrorFor('password') ?? e.message;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transporterSignUpTitle), actions: const [LanguageMenuButton()]),
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
            Row(
              children: [
                _StepDot(filled: true),
                const SizedBox(width: 4),
                _StepDot(filled: false),
                const SizedBox(width: 4),
                _StepDot(filled: false),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.transporterSignUpStepLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.6),
            ),
            const SizedBox(height: 4),
            Text(l10n.transporterSignUpSubtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              inputFormatters: tanzanianPhoneInputFormatters,
              decoration: InputDecoration(hintText: l10n.phoneNumberHint, helperText: l10n.phoneNumberHelperText, errorMaxLines: 2),
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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(hintText: l10n.passwordHint, helperText: l10n.passwordHelperText),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            TermsAgreementCheckbox(value: _acceptedTerms, onChanged: (value) => setState(() => _acceptedTerms = value)),
            if (_errorText != null) ...[const SizedBox(height: 8), Text(_errorText!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.sendVerificationCode.toUpperCase()),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(onPressed: () => context.push('/company-login'), child: Text('${l10n.alreadyRegistered} ${l10n.logIn}')),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(height: 3, color: filled ? AppColors.ctaBlue : AppColors.border));
  }
}

/// Data handed to the OTP screen — a typed class rather than a raw map so
/// the router's `extra` payload can't silently drift out of sync with what
/// OtpScreen expects. Carries the full registration data (not just the
/// phone number) so OtpScreen's "resend" can call requestOtp() again with
/// identical data — mirroring CustomerOtpScreen/CustomerRegistration.
class OtpScreenArgs {
  const OtpScreenArgs({required this.phoneNumber, required this.role, required this.fullName, required this.email, required this.password});

  final String phoneNumber;
  final AccountRole role;
  final String fullName;
  final String email;
  final String password;
}
