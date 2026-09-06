import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/driver_repository.dart';

/// "Add a driver with name + phone (+ optional license photo)" — AppFlow
/// §2.2. Deliberately the simplest form in the app; a driver roster entry
/// carries far less than a truck or company (no verification workflow at
/// all — see the drivers migration's note on why).
class AddDriverScreen extends StatefulWidget {
  AddDriverScreen({super.key, DriverRepository? repository, this.editDriver})
    : repository = repository ?? DriverRepository();

  final DriverRepository repository;
  final Driver? editDriver;

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _licenseNumber = TextEditingController();
  PlatformFile? _licensePhoto;

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final driver = widget.editDriver;
    if (driver != null) {
      _fullName.text = driver.fullName;
      _phoneNumber.text = driver.phoneNumber;
      _licenseNumber.text = driver.licenseNumber ?? '';
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phoneNumber.dispose();
    _licenseNumber.dispose();
    super.dispose();
  }

  Future<void> _pickLicensePhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file != null) setState(() => _licensePhoto = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.repository.save(
        driverId: widget.editDriver?.id,
        fullName: _fullName.text.trim(),
        phoneNumber: _phoneNumber.text.trim(),
        licenseNumber: _licenseNumber.text.trim().isEmpty
            ? null
            : _licenseNumber.text.trim(),
        licensePhoto: _licensePhoto,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editDriver == null ? 'Add driver' : 'Edit driver'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneNumber,
                decoration: const InputDecoration(labelText: 'Phone number'),
                keyboardType: TextInputType.phone,
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseNumber,
                decoration: const InputDecoration(
                  labelText: 'License number (optional)',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickLicensePhoto,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDE1E6)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _licensePhoto != null
                            ? Icons.check_circle
                            : Icons.attach_file,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _licensePhoto?.name ?? 'License photo (optional)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 16),
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
                    : const Text('Save driver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
