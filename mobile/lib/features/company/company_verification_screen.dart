import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'data/company_repository.dart';

/// The two-section verification flow (AppFlow §1): Company Info, then
/// Representative Info (no selfie — dropped from the user's own field
/// list). Implemented as one scrollable form
/// with two clearly labeled sections rather than a full paginated wizard —
/// this is a one-time, sit-down form (not a frequent, on-the-go flow like
/// Post a Job), so the simpler layout is a deliberate scope call, not an
/// oversight.
class CompanyVerificationScreen extends StatefulWidget {
  CompanyVerificationScreen({
    super.key,
    CompanyRepository? repository,
    this.rejectedReason,
  }) : repository = repository ?? CompanyRepository();

  final CompanyRepository repository;

  /// Set when resubmitting after a rejection, to show Admin's reason above
  /// the form rather than making the company go hunting for it again.
  final String? rejectedReason;

  @override
  State<CompanyVerificationScreen> createState() =>
      _CompanyVerificationScreenState();
}

class _CompanyVerificationScreenState extends State<CompanyVerificationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyName = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _tin = TextEditingController();
  final _physicalAddress = TextEditingController();
  final _companyPhone = TextEditingController();
  final _companyEmail = TextEditingController();
  final _repFullName = TextEditingController();
  final _repPosition = TextEditingController();
  final _repNationalIdNumber = TextEditingController();

  PlatformFile? _registrationCertificate;
  PlatformFile? _tinCertificate;
  List<PlatformFile> _otherDocuments = [];
  PlatformFile? _logo;
  PlatformFile? _repIdDocument;

  bool _isSubmitting = false;
  String? _errorText;

  static const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  @override
  void dispose() {
    for (final c in [
      _companyName,
      _registrationNumber,
      _tin,
      _physicalAddress,
      _companyPhone,
      _companyEmail,
      _repFullName,
      _repPosition,
      _repNationalIdNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile(ValueChanged<PlatformFile> onPicked) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true, // ensures `bytes` is populated, required on web
    );
    final file = result?.files.singleOrNull;
    if (file != null) {
      setState(() => onPicked(file));
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file != null) setState(() => _logo = file);
  }

  Future<void> _pickOtherDocuments() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
      allowMultiple: true,
    );
    final files = result?.files;
    if (files != null && files.isNotEmpty) {
      setState(() => _otherDocuments = files);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_registrationCertificate == null ||
        _tinCertificate == null ||
        _repIdDocument == null) {
      setState(
        () => _errorText =
            'Please attach the company registration certificate, TIN certificate, and ID document.',
      );
      return;
    }

    // A confirmation step, not a second validation pass — everything above
    // already checked required fields/attachments are present; this just
    // gives the company one last look before a submission that (per
    // AppFlow §1) locks the form until Admin reviews it.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit for review?'),
        content: const Text(
          'Please confirm all the information and documents you provided are correct. You won\'t be able to edit this submission while it\'s under review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.repository.submit(
        CompanyVerificationSubmission(
          companyName: _companyName.text.trim(),
          registrationNumber: _registrationNumber.text.trim(),
          tin: _tin.text.trim(),
          physicalAddress: _physicalAddress.text.trim(),
          companyPhone: _companyPhone.text.trim(),
          companyEmail: _companyEmail.text.trim().isEmpty
              ? null
              : _companyEmail.text.trim(),
          registrationCertificate: _registrationCertificate!,
          tinCertificate: _tinCertificate!,
          otherDocuments: _otherDocuments,
          logo: _logo,
          repFullName: _repFullName.text.trim(),
          repPosition: _repPosition.text.trim(),
          repNationalIdNumber: _repNationalIdNumber.text.trim(),
          repIdDocument: _repIdDocument!,
        ),
      );
      if (!mounted) return;
      context.go('/company');
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  // Optional field (backend: nullable|email) — only validated when non-empty
  // so a blank value stays valid, but a malformed one is caught before
  // submitting rather than coming back as a raw server error.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _emailPattern.hasMatch(value.trim()) ? null : 'Enter a valid email';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your company')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.rejectedReason != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.statusError.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.statusError.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Previous submission rejected',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.rejectedReason!),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Company Info',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyName,
                decoration: const InputDecoration(labelText: 'Company name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _registrationNumber,
                decoration: const InputDecoration(
                  labelText: 'Registration number',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tin,
                decoration: const InputDecoration(labelText: 'TIN'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _physicalAddress,
                decoration: const InputDecoration(
                  labelText: 'Physical address',
                ),
                maxLines: 2,
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyPhone,
                decoration: const InputDecoration(labelText: 'Company phone'),
                keyboardType: TextInputType.phone,
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyEmail,
                decoration: const InputDecoration(
                  labelText: 'Company email (optional)',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: _optionalEmail,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.image_outlined),
                label: Text(_logo?.name ?? 'Upload company logo (optional)'),
              ),
              const SizedBox(height: 12),
              _FilePickerTile(
                label: 'Company registration certificate',
                file: _registrationCertificate,
                onTap: () => _pickFile((f) => _registrationCertificate = f),
              ),
              const SizedBox(height: 12),
              _FilePickerTile(
                label: 'TIN certificate',
                file: _tinCertificate,
                onTap: () => _pickFile((f) => _tinCertificate = f),
              ),
              const SizedBox(height: 12),
              _FilePickerTile(
                label: 'Other documents (optional)',
                fileCount: _otherDocuments.length,
                onTap: _pickOtherDocuments,
              ),
              const SizedBox(height: 32),
              Text(
                'Representative Info',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _repFullName,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repPosition,
                decoration: const InputDecoration(
                  labelText: 'Position in company',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repNationalIdNumber,
                decoration: const InputDecoration(
                  labelText: 'National ID (NIDA) number',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              _FilePickerTile(
                label: 'ID document',
                file: _repIdDocument,
                onTap: () => _pickFile((f) => _repIdDocument = f),
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
                    : const Text('Submit for review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilePickerTile extends StatelessWidget {
  const _FilePickerTile({
    required this.label,
    this.file,
    this.fileCount = 0,
    required this.onTap,
  });

  final String label;

  /// Single-file mode (registration certificate, TIN certificate, ID
  /// document) — shows the picked file's name once selected.
  final PlatformFile? file;

  /// Multi-file mode ("other documents") — shows a count instead, since
  /// several filenames wouldn't fit one tile. 0 means nothing selected yet
  /// in this mode.
  final int fileCount;

  final VoidCallback onTap;

  bool get _hasSelection => file != null || fileCount > 0;

  String get _displayText {
    if (file != null) return file!.name;
    if (fileCount > 0)
      return '$fileCount file${fileCount == 1 ? '' : 's'} selected';

    return label;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _hasSelection ? Icons.check_circle : Icons.attach_file,
              color: _hasSelection
                  ? AppColors.statusLive
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_displayText, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
