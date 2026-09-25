import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'password_field.dart';

/// Asks for the current password before a security-sensitive change (e.g.
/// turning two-factor authentication on or off). Returns the entered
/// password, or null if the user cancelled.
Future<String?> showConfirmPasswordDialog(BuildContext context) {
  return showDialog<String>(context: context, builder: (_) => const _ConfirmPasswordDialog());
}

class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog();

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.enterYourPassword);
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.confirmPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasswordField(
            controller: _controller,
            labelText: l10n.currentPasswordHint,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancelLabel)),
        ElevatedButton(onPressed: _submit, child: Text(l10n.continueLabel)),
      ],
    );
  }
}
