import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/truck_repository.dart';
import 'truck_catalog.dart';

/// Truck registration (AppFlow §2.2): vehicle info, then documents, in one
/// scrollable form with two sections — same pacing/pattern as
/// CompanyVerificationScreen, for the same reason (a one-time, sit-down
/// form rather than a frequent on-the-go flow).
///
/// Once a truck has real details on file (anything other than a bare
/// GPS-imported placeholder — see [_isLocked]), registration number,
/// make/model, and documents render read-only: they describe a specific
/// physical vehicle and shouldn't casually change after the fact. Only
/// capacity and type stay editable from then on — the backend enforces
/// the same split (SubmitTruckRequest's "locked" branch), this is just
/// the UI reflecting it. The first time real details are ever submitted
/// (a fresh truck, or completing a GPS import), a confirmation dialog
/// makes sure the company means it before that lock kicks in.
class AddTruckScreen extends StatefulWidget {
  AddTruckScreen({super.key, TruckRepository? repository, this.editTruck})
    : repository = repository ?? TruckRepository();

  final TruckRepository repository;

  /// Set when editing an existing truck rather than registering a new one
  /// — prefills its vehicle details (photos/documents are always re-picked,
  /// since the picker holds no existing files) and targets the update
  /// endpoint instead of create. Used both to correct a truck's details
  /// and to complete a bare GPS-imported one.
  final Truck? editTruck;

  @override
  State<AddTruckScreen> createState() => _AddTruckScreenState();
}

class _AddTruckScreenState extends State<AddTruckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registrationNumber = TextEditingController();
  // Not a TextEditingController: Autocomplete manages its own internal
  // controller for the make/model field (see _buildMakeModelField), so
  // this is just the plain value it reports back via onChanged/onSelected.
  String _makeModel = '';
  final _vehicleType = TextEditingController();
  String? _selectedTruckType;
  final _capacityTons = TextEditingController();

  final List<PlatformFile> _photos = [];
  PlatformFile? _registrationCard;
  PlatformFile? _insurance;
  PlatformFile? _roadworthinessPermit;

  bool _isSubmitting = false;
  String? _errorText;

  static const _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  /// Once a truck has real details on file (i.e. it isn't a bare
  /// GPS-imported placeholder still awaiting its first real submit — see
  /// Truck.isGpsImported), only capacity/type stay editable. Mirrors the
  /// backend's own "locked" check (SubmitTruckRequest::rules()) exactly.
  bool get _isLocked =>
      widget.editTruck != null && !widget.editTruck!.isGpsImported;

  @override
  void initState() {
    super.initState();
    final truck = widget.editTruck;
    if (truck != null) {
      _registrationNumber.text = truck.registrationNumber;
      _makeModel = truck.makeModel;
      _vehicleType.text = truck.vehicleType;
      _capacityTons.text = truck.capacityTons.toString();
      _selectedTruckType = kTruckTypes.contains(truck.vehicleType)
          ? truck.vehicleType
          : kOtherTruckType;
    }
  }

  @override
  void dispose() {
    for (final c in [_registrationNumber, _vehicleType, _capacityTons]) {
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

    // Not locked means this is the first time real details are ever being
    // submitted for this truck (a fresh create, or completing a bare GPS
    // import) — the one moment worth pausing on, since everything but
    // capacity/type becomes locked the instant this succeeds.
    if (!_isLocked && !await _confirmDetails()) return;

    // A document only has to be attached when the truck doesn't already
    // have one on file (the server applies the same rule) — so editing a
    // capacity keeps the existing insurance PDF, while completing a bare
    // GPS import, which has no documents at all, still has to supply them.
    if (!_isLocked &&
        ((_photos.isEmpty && !_hasPhotosOnFile) ||
            (_registrationCard == null && !_hasRegistrationCardOnFile) ||
            (_insurance == null && !_hasInsuranceOnFile))) {
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
          makeModel: _makeModel.trim(),
          vehicleType: _vehicleType.text.trim(),
          capacityTons: double.parse(_capacityTons.text.trim()),
          photos: _photos,
          registrationCard: _registrationCard,
          insurance: _insurance,
          roadworthinessPermit: _roadworthinessPermit,
        ),
        editTruckId: widget.editTruck?.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _confirmDetails() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm truck details'),
        content: const Text(
          'Please make sure these details are accurate and belong to this '
          'truck. Registration number, make/model, and documents can\'t be '
          'changed afterward — only capacity and type will stay editable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm & save'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  bool get _hasPhotosOnFile => widget.editTruck?.photoUrls.isNotEmpty ?? false;
  bool get _hasRegistrationCardOnFile =>
      widget.editTruck?.registrationCardUrl != null;
  bool get _hasInsuranceOnFile => widget.editTruck?.insuranceUrl != null;

  /// Locked: a plain read-only field (Autocomplete has nothing useful to
  /// offer once this can't be changed). Otherwise a free-text field with
  /// make+model suggestions (kTruckMakeModels) filtered as the user
  /// types — still fully free text, matching nothing just means no
  /// suggestions pop up.
  Widget _buildMakeModelField() {
    const label = 'Make / model (e.g. Isuzu FVR, Scania G410)';
    if (_isLocked) {
      return TextFormField(
        initialValue: _makeModel,
        enabled: false,
        decoration: const InputDecoration(labelText: label),
      );
    }

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _makeModel),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return kTruckMakeModels.where(
          (option) => option.toLowerCase().contains(query),
        );
      },
      onSelected: (selection) => setState(() => _makeModel = selection),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: label),
          validator: _required,
          onChanged: (value) => _makeModel = value,
        );
      },
    );
  }

  /// A dropdown of common body types (kTruckTypes) plus an "Other" escape
  /// hatch that reveals a plain text field — this stays editable even on
  /// a locked truck (only registration/make-model/documents are locked).
  Widget _buildVehicleTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedTruckType,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final type in kTruckTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          validator: (value) => value == null ? 'Required' : null,
          onChanged: (value) {
            setState(() {
              _selectedTruckType = value;
              if (value != null && value != kOtherTruckType) {
                _vehicleType.text = value;
              } else {
                _vehicleType.clear();
              }
            });
          },
        ),
        if (_selectedTruckType == kOtherTruckType) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _vehicleType,
            decoration: const InputDecoration(labelText: 'Type (custom)'),
            validator: _required,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editTruck == null
              ? 'Add truck'
              : widget.editTruck!.isGpsImported
              ? 'Add truck details'
              : 'Edit truck',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vehicle Info',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_isLocked) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoTint,
                    border: Border.all(color: const Color(0xFFD6EBFF)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: AppColors.ctaBlue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'These details are locked once confirmed. Only capacity and type can be changed.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.ctaBluePressed, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _registrationNumber,
                enabled: !_isLocked,
                decoration: const InputDecoration(
                  labelText: 'Registration number',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              _buildMakeModelField(),
              const SizedBox(height: 12),
              _buildVehicleTypeField(),
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
              if (!_isLocked) ...[
                const SizedBox(height: 24),
                Text(
                  'Documents',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _photos.length >= 5 ? null : _pickPhotos,
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
                          _photos.isEmpty && !_hasPhotosOnFile
                              ? Icons.add_a_photo_outlined
                              : Icons.check_circle,
                          color: _photos.isEmpty && !_hasPhotosOnFile
                              ? AppColors.textSecondary
                              : AppColors.statusLive,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _photos.isNotEmpty
                              ? '${_photos.length} photo(s) selected'
                              : _hasPhotosOnFile
                              ? 'Photos on file — tap to replace'
                              : 'Add photos (up to 5)',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FilePickerTile(
                  label: 'Registration card',
                  file: _registrationCard,
                  alreadyOnFile: _hasRegistrationCardOnFile,
                  onTap: () => _pickFile((f) => _registrationCard = f),
                ),
                const SizedBox(height: 12),
                _FilePickerTile(
                  label: 'Insurance',
                  file: _insurance,
                  alreadyOnFile: _hasInsuranceOnFile,
                  onTap: () => _pickFile((f) => _insurance = f),
                ),
                const SizedBox(height: 12),
                _FilePickerTile(
                  label: 'Roadworthiness / permit (if applicable)',
                  file: _roadworthinessPermit,
                  onTap: () => _pickFile((f) => _roadworthinessPermit = f),
                ),
              ],
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
                    : Text(
                        widget.editTruck == null
                            ? 'Register truck'
                            : 'Save changes',
                      ),
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
    this.alreadyOnFile = false,
  });

  final String label;
  final PlatformFile? file;
  final VoidCallback onTap;

  /// Editing a truck that already has this document — nothing needs
  /// attaching unless the company actually wants to replace it, so the
  /// tile says so rather than reading as an empty required field.
  final bool alreadyOnFile;

  @override
  Widget build(BuildContext context) {
    final isPicked = file != null;
    final isSatisfied = isPicked || alreadyOnFile;

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
              isSatisfied ? Icons.check_circle : Icons.attach_file,
              color: isSatisfied
                  ? AppColors.statusLive
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPicked
                    ? file!.name
                    : alreadyOnFile
                    ? '$label — on file, tap to replace'
                    : label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
