import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'data/job_repository.dart';
import 'job_geo.dart';
import 'shipment_posted_screen.dart';

const _cargoTypes = ['Container', 'General cargo', 'Machinery', 'Construction materials', 'Other'];
const _containerSizes = ['20ft', '40ft', 'Other'];

/// Post a Job (AppFlow §3.2): locations, container/cargo details, timing,
/// notes. Restyled to the mockup's step-by-step wizard — three real steps
/// (Route, Cargo details, Pickup & notes), not the mockup's four: the
/// mockup's fourth step sets a customer "budget", but this app has no such
/// field (JobSubmission has none — a price only exists once a transporter's
/// bid is accepted), so that step isn't reproduced.
///
/// Location entry is plain address + latitude/longitude fields, not a map
/// pin-drop picker: no Google Maps API key is provisioned yet (an empty
/// key would just render broken tiles), so a real map picker would be
/// untestable regardless of how it's built. The backend already stores and
/// serves real PostGIS coordinates either way — swapping in a GoogleMap-
/// based picker later, once a key exists, only touches this screen's input
/// widgets, not the data layer or backend.
class PostJobScreen extends StatefulWidget {
  PostJobScreen({super.key, JobRepository? repository, this.prefillReturnFrom}) : repository = repository ?? JobRepository();

  final JobRepository repository;

  /// Customer Plus benefit (Phase 10.19): "Post return shipment" on a
  /// completed job opens this screen with the route reversed (the
  /// original dropoff becomes the new pickup, and vice versa) and the
  /// same container type/size carried over — real data already on hand
  /// from that job, not fabricated. Weight/cargo description are left
  /// blank since the return cargo is genuinely different.
  final Job? prefillReturnFrom;

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

  int _step = 0;
  DateTime? _pickupWindowStart;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    for (final c in [_pickupLat, _pickupLng, _dropoffLat, _dropoffLng]) {
      c.addListener(() => setState(() {}));
    }

    final returnFrom = widget.prefillReturnFrom;
    if (returnFrom != null) {
      _pickupAddress.text = returnFrom.dropoffAddress;
      _pickupLat.text = returnFrom.dropoffLat?.toString() ?? '';
      _pickupLng.text = returnFrom.dropoffLng?.toString() ?? '';
      _dropoffAddress.text = returnFrom.pickupAddress;
      _dropoffLat.text = returnFrom.pickupLat?.toString() ?? '';
      _dropoffLng.text = returnFrom.pickupLng?.toString() ?? '';
      _containerType.text = returnFrom.containerType;
      _containerSize.text = returnFrom.containerSize;
    }
  }

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

  double? get _distanceKm {
    final pLat = double.tryParse(_pickupLat.text.trim());
    final pLng = double.tryParse(_pickupLng.text.trim());
    final dLat = double.tryParse(_dropoffLat.text.trim());
    final dLng = double.tryParse(_dropoffLng.text.trim());
    if (pLat == null || pLng == null || dLat == null || dLng == null) return null;
    return kmBetween(pLat, pLng, dLat, dLng);
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step += 1);
  }

  void _back() => setState(() => _step -= 1);

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
      final job = await widget.repository.post(
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
      // A push-replace, not a pop: the caller's `await Navigator.push<bool>(...)`
      // future resolves right now via `result: true` (so CustomerHomeShell
      // refreshes Jobs immediately), while ShipmentPostedScreen takes this
      // route's place in the stack — no separate confirmation dialog needed.
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ShipmentPostedScreen(job: job)), result: true);
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
    const stepTitles = ['Where are you moving cargo?', 'Cargo details', 'Pickup & notes'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Shipment'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Step ${_step + 1} of 3', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(left: i == 0 ? 20 : 2, right: i == 2 ? 20 : 2),
                    color: i <= _step ? AppColors.ctaBlue : const Color(0xFFE4E5E8),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      stepTitles[_step],
                      style: const TextStyle(
                        fontFamily: 'Barlow Condensed',
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    switch (_step) {
                      0 => _RouteStep(state: this),
                      1 => _CargoStep(state: this),
                      _ => _PickupStep(state: this),
                    },
                    if (_errorText != null) ...[const SizedBox(height: 16), Text(_errorText!, style: const TextStyle(color: Colors.red))],
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    SizedBox(
                      width: 96,
                      child: OutlinedButton(onPressed: _back, child: const Text('BACK')),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : (_step < 2 ? _continue : _submit),
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_step < 2 ? 'CONTINUE' : 'POST SHIPMENT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({required this.state});

  final _PostJobScreenState state;

  @override
  Widget build(BuildContext context) {
    final distance = state._distanceKm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Pick-up and drop-off points for this load.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Text('Pickup', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: state._pickupAddress,
          decoration: const InputDecoration(labelText: 'Pickup address'),
          validator: state._required,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: state._pickupLat,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: state._requiredCoordinate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: state._pickupLng,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: state._requiredCoordinate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Drop-off', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: state._dropoffAddress,
          decoration: const InputDecoration(labelText: 'Drop-off address'),
          validator: state._required,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: state._dropoffLat,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: state._requiredCoordinate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: state._dropoffLng,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: state._requiredCoordinate,
              ),
            ),
          ],
        ),
        if (distance != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estimated distance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  '${distance.toStringAsFixed(0)} km',
                  style: const TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CargoStep extends StatelessWidget {
  const _CargoStep({required this.state});

  final _PostJobScreenState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([state._containerType, state._containerSize]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('The more precise this is, the better your bids.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            const Text(
              'Cargo type',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLabel),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _cargoTypes)
                  _Chip(label: type, selected: state._containerType.text == type, onTap: () => state._containerType.text = type),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: state._containerType,
              decoration: const InputDecoration(labelText: 'Container type (e.g. Dry Van, Reefer)'),
              validator: state._required,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: state._approxWeightTons,
                    decoration: const InputDecoration(labelText: 'Weight (tons, optional)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Container size',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLabel),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final size in _containerSizes)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(
                        label: size,
                        selected: state._containerSize.text == size,
                        onTap: () => state._containerSize.text = size,
                        centered: true,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: state._containerSize,
              decoration: const InputDecoration(labelText: 'Container size (e.g. 20ft, 40ft)'),
              validator: state._required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: state._cargoDescription,
              decoration: const InputDecoration(labelText: 'Cargo description (optional)'),
              maxLines: 2,
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.centered = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: centered ? 0 : 13, vertical: 8),
        alignment: centered ? Alignment.center : null,
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.ctaBlue : AppColors.border, width: selected ? 1.5 : 1),
          color: selected ? AppColors.infoTint : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.ctaBluePressed : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PickupStep extends StatelessWidget {
  const _PickupStep({required this.state});

  final _PostJobScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('When and exactly where the truck should collect.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        InkWell(
          onTap: state._pickWindowStart,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Preferred pickup date & time'),
            child: Text(
              state._pickupWindowStart == null
                  ? 'Tap to choose'
                  : DateFormat('d MMM yyyy, HH:mm').format(state._pickupWindowStart!.toLocal()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: state._customerNotes,
          decoration: const InputDecoration(labelText: 'Notes for companies (optional)'),
          maxLines: 3,
        ),
        const SizedBox(height: 8),
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
              Icon(Icons.info_outline, size: 16, color: AppColors.ctaBlue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transporters see the district, not your exact address, until you accept an offer.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.ctaBluePressed, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: Listenable.merge([
            state._pickupAddress,
            state._dropoffAddress,
            state._containerType,
            state._containerSize,
            state._approxWeightTons,
          ]),
          builder: (context, _) {
            final rows = <(String, String)>[
              ('Route', '${state._pickupAddress.text} → ${state._dropoffAddress.text}'),
              (
                'Cargo',
                [
                  state._containerType.text,
                  state._containerSize.text,
                  if (state._approxWeightTons.text.trim().isNotEmpty) '${state._approxWeightTons.text} t',
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              if (state._pickupWindowStart != null) ('Pickup', DateFormat('d MMM yyyy, HH:mm').format(state._pickupWindowStart!.toLocal())),
            ];

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    color: AppColors.surfaceSubtle,
                    child: const Text(
                      'SHIPMENT SUMMARY',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLabel, letterSpacing: 0.7),
                    ),
                  ),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(row.$1, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                          ),
                          Expanded(
                            child: Text(
                              row.$2,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
