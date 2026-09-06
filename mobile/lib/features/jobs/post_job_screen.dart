import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import 'data/job_repository.dart';

/// Post a Job (AppFlow §3.2): locations, container/cargo details, timing,
/// notes — one scrollable form with clear sections, same simplification
/// (and reasoning) as CompanyVerificationScreen/AddTruckScreen.
///
/// Location entry is plain address + latitude/longitude fields, not a map
/// pin-drop picker: no Google Maps API key is provisioned yet (an empty
/// key would just render broken tiles), so a real map picker would be
/// untestable regardless of how it's built. The backend already stores and
/// serves real PostGIS coordinates either way — swapping in a GoogleMap-
/// based picker later, once a key exists, only touches this screen's input
/// widgets, not the data layer or backend.
class PostJobScreen extends StatefulWidget {
  PostJobScreen({super.key, JobRepository? repository}) : repository = repository ?? JobRepository();

  final JobRepository repository;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final _pickupAddress = TextEditingController();
  final _pickupLat = TextEditingController();
  final _pickupLng = TextEditingController();
  final _dropoffAddress = TextEditingController();
  final _dropoffLat = TextEditingController();
  final _dropoffLng = TextEditingController();
  final _containerType = TextEditingController();
  final _containerSize = TextEditingController();
  final _approxWeightTons = TextEditingController();
  final _cargoDescription = TextEditingController();
  final _customerNotes = TextEditingController();

  DateTime? _pickupWindowStart;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    for (final c in [
      _pickupAddress,
      _pickupLat,
      _pickupLng,
      _dropoffAddress,
      _dropoffLat,
      _dropoffLng,
      _containerType,
      _containerSize,
      _approxWeightTons,
      _cargoDescription,
      _customerNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickWindowStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    setState(() {
      _pickupWindowStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickupWindowStart == null) {
      setState(() => _errorText = 'Please choose a preferred pickup date and time.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.repository.post(
        JobSubmission(
          pickupAddress: _pickupAddress.text.trim(),
          pickupLat: double.parse(_pickupLat.text.trim()),
          pickupLng: double.parse(_pickupLng.text.trim()),
          dropoffAddress: _dropoffAddress.text.trim(),
          dropoffLat: double.parse(_dropoffLat.text.trim()),
          dropoffLng: double.parse(_dropoffLng.text.trim()),
          containerType: _containerType.text.trim(),
          containerSize: _containerSize.text.trim(),
          approxWeightTons: _approxWeightTons.text.trim().isEmpty ? null : double.tryParse(_approxWeightTons.text.trim()),
          cargoDescription: _cargoDescription.text.trim().isEmpty ? null : _cargoDescription.text.trim(),
          preferredPickupWindowStart: _pickupWindowStart!,
          customerNotes: _customerNotes.text.trim().isEmpty ? null : _customerNotes.text.trim(),
        ),
      );
      if (!mounted) return;
      context.pop(true);
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _required(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

  String? _requiredCoordinate(String? value) {
    if (_required(value) != null) return 'Required';

    return double.tryParse(value!.trim()) == null ? 'Enter a number' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pickup', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pickupAddress,
                decoration: const InputDecoration(labelText: 'Pickup address'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pickupLat,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: _requiredCoordinate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _pickupLng,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: _requiredCoordinate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Drop-off', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dropoffAddress,
                decoration: const InputDecoration(labelText: 'Drop-off address'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dropoffLat,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: _requiredCoordinate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _dropoffLng,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: _requiredCoordinate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Cargo Details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _containerType,
                decoration: const InputDecoration(labelText: 'Container type (e.g. Dry Van, Reefer)'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _containerSize,
                decoration: const InputDecoration(labelText: 'Container size (e.g. 20ft, 40ft)'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _approxWeightTons,
                decoration: const InputDecoration(labelText: 'Approx. weight (tons, optional)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cargoDescription,
                decoration: const InputDecoration(labelText: 'Cargo description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Text('Timing & Notes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickWindowStart,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Preferred pickup date & time'),
                  child: Text(
                    _pickupWindowStart == null ? 'Tap to choose' : _pickupWindowStart!.toLocal().toString(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerNotes,
                decoration: const InputDecoration(labelText: 'Notes for companies (optional)'),
                maxLines: 3,
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Post job'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
