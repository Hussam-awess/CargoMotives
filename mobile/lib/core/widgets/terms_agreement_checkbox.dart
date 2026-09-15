import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// The required "I agree to the Terms and Conditions and Privacy Policy"
/// checkbox on both sign-up screens (Company's PhoneEntryScreen, Customer's
/// CustomerRegisterScreen) — a single shared widget rather than duplicating
/// this in both, since it owns two TapGestureRecognizers that must be
/// disposed correctly (a StatefulWidget concern, not just a stateless
/// row of text).
///
/// "Terms and Conditions" and "Privacy Policy" open the same real,
/// server-rendered pages Settings' own legal section already links to
/// (/legal/terms, /legal/privacy) — built from four separate l10n pieces
/// (prefix/link/middle/link/suffix) rather than one sentence, since a
/// single translated string can't carry which words are tappable.
///
/// The checkbox itself is the sole toggle target (not "tap anywhere on the
/// row", as it was before this had real links) — the two spans below have
/// their own tap recognizers, which would otherwise compete with a
/// whole-row InkWell in the same gesture arena.
class TermsAgreementCheckbox extends StatefulWidget {
  const TermsAgreementCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<TermsAgreementCheckbox> createState() => _TermsAgreementCheckboxState();
}

class _TermsAgreementCheckboxState extends State<TermsAgreementCheckbox> {
  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()..onTap = () => _openLegal('/legal/terms');
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()..onTap = () => _openLegal('/legal/privacy');

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openLegal(String path) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotOpenUri(uri.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final linkStyle = TextStyle(
      fontSize: 12.5,
      height: 1.4,
      color: AppColors.ctaBlue,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: widget.value, onChanged: (value) => widget.onChanged(value ?? false)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12.5, color: AppColors.textLabel, height: 1.4),
                children: [
                  TextSpan(text: l10n.agreeToTermsPrefix),
                  TextSpan(text: l10n.termsAndConditionsLabel, style: linkStyle, recognizer: _termsRecognizer),
                  TextSpan(text: l10n.agreeToTermsMiddle),
                  TextSpan(text: l10n.privacyPolicyLinkLabel, style: linkStyle, recognizer: _privacyRecognizer),
                  TextSpan(text: l10n.agreeToTermsSuffix),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
