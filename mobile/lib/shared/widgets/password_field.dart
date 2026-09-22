import 'package:flutter/material.dart';

/// A password TextField with a tap-to-reveal eye icon — a drop-in
/// replacement for `TextField(obscureText: true, ...)` wherever a user
/// types a password, so a typo isn't just guessed at blind.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      obscureText: _obscure,
      decoration: InputDecoration(
        hintText: widget.hintText,
        labelText: widget.labelText,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          tooltip: _obscure ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}
