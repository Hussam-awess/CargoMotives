import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/truck_repository.dart';

/// Truck registration (AppFlow §2.2): vehicle info, then documents, in one
/// scrollable form with two sections — same pacing/pattern as
/// CompanyVerificationScreen, for the same reason (a one-time, sit-down
/// form rather than a frequent on-the-go flow).
class AddTruckScreen extends StatefulWidget {
  AddTruckScreen({super.key, TruckRepository? repository, this.resubmitTruck})
    : repository = repository ?? TruckRepository();

  final TruckRepository repository;

  /// Set when resubmitting a rejected truck — prefills nothing (the
  /// company re-enters details, since the photos/documents that caused
  /// the rejection need replacing anyway), but shows the rejection reason
  /// and targets the update endpoint instead of create.
  final Truck? resubmitTruck;

  @override
  State<AddTruckScreen> createState() => _AddTruckScreenState();
}

class _AddTruckScreenState extends State<AddTruckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registrationNumber = TextEditingController();
  final _makeModel = TextEditingController();
  final _vehicleType = TextEditingController();
  final _capacityTons = TextEditingController();

  final List<PlatformFile> _photos = [];
  PlatformFile? _registrationCard;
  PlatformFile? _insurance;
  PlatformFile? _roadworthinessPermit;

  bool _isSubmitting = false;
  String? _errorText;

  static const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  @override
  void initState() {
    super.initState();
    final truck = widget.resubmitTruck;
    if (truck != null) {
      _registrationNumber.text = truck.registrationNumber;
      _makeModel.text = truck.makeModel;
      _vehicleType.text = truck.vehicleType;
      _capacityTons.text = truck.capacityTons.toString();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _registrationNumber,
      _makeModel,
      _vehicleType,
      _capacityTons,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() => _photos.addAll(result.files.take(5 - _photos.length)));
    }
  }

  Future<void> _pickFile(ValueChanged<PlatformFile> onPicked) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file != null) setState(() => onPicked(file));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photos.isEmpty || _registrationCard == null || _insurance == null) {
      setState(
        () => _errorText =
            'Please attach at least one photo, the registration card, and insurance.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.repository.submit(
        TruckSubmission(
          registrationNumber: _registrationNumber.text.trim(),
          makeModel: _makeModel.text.trim(),
          vehicleType: _vehicleType.text.trim(),
          capacityTons: double.parse(_capacityTons.text.trim()),
          photos: _photos,
          registrationCard: _registrationCard!,
          insurance: _insurance!,
          roadworthinessPermit: _roadworthinessPermit,
        ),
        resubmitTruckId: widget.resubmitTruck?.id,
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
        title: Text(
          widget.resubmitTruck == null ? 'Add truck' : 'Resubmit truck',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.resubmitTruck?.rejectedReason != null) ...[
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
                      Text(widget.resubmitTruck!.rejectedReason!),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Vehicle Info',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registrationNumber,
                decoration: const InputDecoration(
                  labelText: 'Registration number',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _makeModel,
                decoration: const InputDecoration(labelText: 'Make / model'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Type (e.g. Flatbed, Tanker)',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacityTons,
                decoration: const InputDecoration(labelText: 'Capacity (tons)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (_required(value) != null) return 'Required';
                  return double.tryParse(value!.trim()) == null
                      ? 'Enter a number'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              Text('Documents', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              InkWell(
                onTap: _photos.length >= 5 ? null : _pickPhotos,
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
                        _photos.isEmpty
                            ? Icons.add_a_photo_outlined
                            : Icons.check_circle,
                        color: _photos.isEmpty
                            ? const Color(0xFF6B7280)
                            : AppColors.statusLive,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _photos.isEmpty
                            ? 'Add photos (up to 5)'
                            : '${_photos.length} photo(s) selected',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _FilePickerTile(
                label: 'Registration card',
                file: _registrationCard,
                onTap: () => _pickFile((f) => _registrationCard = f),
              ),
              const SizedBox(height: 12),
              _FilePickerTile(
                label: 'Insurance',
                file: _insurance,
                onTap: () => _pickFile((f) => _insurance = f),
              ),
              const SizedBox(height: 12),
              _FilePickerTile(
                label: 'Roadworthiness / permit (if applicable)',
                file: _roadworthinessPermit,
                onTap: () => _pickFile((f) => _roadworthinessPermit = f),
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
    required this.file,
    required this.onTap,
  });

  final String label;
  final PlatformFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              file != null ? Icons.check_circle : Icons.attach_file,
              color: file != null
                  ? AppColors.statusLive
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(file?.name ?? label, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
