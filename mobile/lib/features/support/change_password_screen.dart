import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../auth/data/auth_repository.dart';

/// Real, authenticated "change password" (ProfileController::changePassword)
/// — shared by both Customer and Transporter Company Settings screens, same
/// as every other cross-role `/auth/profile/*` endpoint (see
/// EditProfileScreen). Distinct from the forgot-password flow reachable
/// from the login screens: this one requires the CURRENT password, since a
/// signed-in session alone isn't strong enough proof for a change this
/// sensitive.
class ChangePasswordScreen extends StatefulWidget {
  ChangePasswordScreen({
    super.key,
    AuthRepository? authRepository,
    this.onForgotPassword,
  }) : authRepository = authRepository ?? AuthRepository();

  final AuthRepository authRepository;

  /// Opens the caller's role-appropriate forgot-password screen (this
  /// screen has no repository type in common between Customer and
  /// Company, so it can't construct either itself) — null hides the link
  /// entirely rather than rendering one that does nothing.
  final VoidCallback? onForgotPassword;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _serverError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  String? _validateNew(String? value) {
    if (_required(value) != null) return 'Required';
    if (value!.length < 8) return 'At least 8 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (_required(value) != null) return 'Required';
    if (value != _newController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });

    try {
      await widget.authRepository.changePassword(
        currentPassword: _currentController.text,
        password: _newController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password changed.')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _serverError =
            e.firstErrorFor('current_password') ??
            e.firstErrorFor('password') ??
            e.message,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_serverError != null) ...[
                Text(
                  _serverError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _currentController,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                obscureText: true,
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                decoration: const InputDecoration(labelText: 'New password'),
                obscureText: true,
                validator: _validateNew,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                obscureText: true,
                validator: _validateConfirm,
              ),
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
                    : const Text('Save password'),
              ),
              if (widget.onForgotPassword != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: widget.onForgotPassword,
                    child: const Text('or forgot password?'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
