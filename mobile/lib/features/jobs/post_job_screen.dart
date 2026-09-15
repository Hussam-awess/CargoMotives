import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'data/job_repository.dart';
import 'job_geo.dart';
import 'route_picker_map.dart';
import 'shipment_posted_screen.dart';

const _cargoTypes = [
  'Container',
  'General cargo',
  'Machinery',
  'Construction materials',
  'Other',
];
const _containerSizes = ['20ft', '40ft', 'Other'];

/// Post a Job (AppFlow §3.2): locations, container/cargo details, timing,
/// notes. Restyled to the mockup's step-by-step wizard — three real steps
/// (Route, Cargo details, Pickup & notes), not the mockup's four (its
/// separate "budget" step is folded into Cargo details here instead,
/// since JobSubmission's `budgetPrice` is genuinely optional, not the
/// mockup's own required flow gate).
///
/// Location entry is a real, searchable route picker (RoutePickerMap — one
/// combined OpenStreetMap map for both points, not two separate ones) above
/// the address/latitude/longitude fields — searching a place or tapping the
/// map fills those same fields rather than replacing them, so a customer
/// who already knows the exact coordinates can still type them directly.
class PostJobScreen extends StatefulWidget {
  PostJobScreen({super.key, JobRepository? repository, this.prefillReturnFrom})
    : repository = repository ?? JobRepository();

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
  final _budgetPrice = TextEditingController();

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
      _budgetPrice,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The real road-following distance from RoutePickerMap, when routing
  /// succeeded — preferred over the straight-line haversine estimate
  /// below so the form never shows two different numbers for the same
  /// trip (the map's own route card, and this "Estimated distance" one).
  double? _routeDistanceKm;

  void _setRouteDistanceKm(double? km) => setState(() => _routeDistanceKm = km);

  double? get _distanceKm {
    if (_routeDistanceKm != null) return _routeDistanceKm;

    final pLat = double.tryParse(_pickupLat.text.trim());
    final pLng = double.tryParse(_pickupLng.text.trim());
    final dLat = double.tryParse(_dropoffLat.text.trim());
    final dLng = double.tryParse(_dropoffLng.text.trim());
    if (pLat == null || pLng == null || dLat == null || dLng == null)
      return null;
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

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _pickupWindowStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickupWindowStart == null) {
      setState(
        () => _errorText = 'Please choose a preferred pickup date and time.',
      );
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
          approxWeightTons: _approxWeightTons.text.trim().isEmpty
              ? null
              : double.tryParse(_approxWeightTons.text.trim()),
          cargoDescription: _cargoDescription.text.trim().isEmpty
              ? null
              : _cargoDescription.text.trim(),
          preferredPickupWindowStart: _pickupWindowStart!,
          customerNotes: _customerNotes.text.trim().isEmpty
              ? null
              : _customerNotes.text.trim(),
          budgetPrice: _budgetPrice.text.trim().isEmpty
              ? null
              : double.tryParse(_budgetPrice.text.trim()),
        ),
      );
      if (!mounted) return;
      // A push-replace, not a pop: the caller's `await Navigator.push<bool>(...)`
      // future resolves right now via `result: true` (so CustomerHomeShell
      // refreshes Jobs immediately), while ShipmentPostedScreen takes this
      // route's place in the stack — no separate confirmation dialog needed.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ShipmentPostedScreen(job: job)),
        result: true,
      );
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  String? _requiredCoordinate(String? value) {
    if (_required(value) != null) return 'Required';

    return double.tryParse(value!.trim()) == null ? 'Enter a number' : null;
  }

  void _setPickupPoint(LatLng point, [String? address]) {
    setState(() {
      _pickupLat.text = point.latitude.toStringAsFixed(6);
      _pickupLng.text = point.longitude.toStringAsFixed(6);
      if (address != null) _pickupAddress.text = address;
    });
  }

  void _setDropoffPoint(LatLng point, [String? address]) {
    setState(() {
      _dropoffLat.text = point.latitude.toStringAsFixed(6);
      _dropoffLng.text = point.longitude.toStringAsFixed(6);
      if (address != null) _dropoffAddress.text = address;
    });
  }

  @override
  Widget build(BuildContext context) {
    const stepTitles = [
      'Where are you moving cargo?',
      'Cargo details',
      'Pickup & notes',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Shipment'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Step ${_step + 1} of 3',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
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
                    margin: EdgeInsets.only(
                      left: i == 0 ? 20 : 2,
                      right: i == 2 ? 20 : 2,
                    ),
                    color: i <= _step ? AppColors.ctaBlue : AppColors.border,
                  ),
                ),
            ],
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                // Forces a fresh Scrollable per step — without this, all
                // three steps share one persistent scroll position (only
                // the child content swaps), so scrolling deep into a long
                // step and continuing lands the next, shorter step already
                // scrolled past its own content instead of at the top. Not
                // just a test artifact: adding the pickup/drop-off maps
                // made Route long enough for this to actually bite a real
                // user for the first time.
                key: ValueKey(_step),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      stepTitles[_step],
                      style: TextStyle(
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
                    if (_errorText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
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
                      child: OutlinedButton(
                        onPressed: _back,
                        child: const Text('BACK'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : (_step < 2 ? _continue : _submit),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
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

/// Null unless both fields already hold a valid number — used to decide
/// whether a pickup/drop-off map should show an existing pin (e.g. a
/// return-job prefill) or start blank at a city-wide default view.
LatLng? _pointFrom(TextEditingController lat, TextEditingController lng) {
  final parsedLat = double.tryParse(lat.text.trim());
  final parsedLng = double.tryParse(lng.text.trim());
  if (parsedLat == null || parsedLng == null) return null;

  return LatLng(parsedLat, parsedLng);
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
        Text(
          'Search for a place or tap the map to set pick-up (green) and drop-off (red).',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        RoutePickerMap(
          initialPickup: _pointFrom(state._pickupLat, state._pickupLng),
          initialDropoff: _pointFrom(state._dropoffLat, state._dropoffLng),
          onPickupChanged: state._setPickupPoint,
          onDropoffChanged: state._setDropoffPoint,
          onRouteDistanceChanged: state._setRouteDistanceKm,
        ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: state._requiredCoordinate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: state._pickupLng,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: state._requiredCoordinate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: state._dropoffLng,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
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
                const Text(
                  'Estimated distance',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${distance.toStringAsFixed(0)} km',
                  style: TextStyle(
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
            Text(
              'The more precise this is, the better your bids.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              'Cargo type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _cargoTypes)
                  _Chip(
                    label: type,
                    selected: state._containerType.text == type,
                    onTap: () => state._containerType.text = type,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: state._containerType,
              decoration: const InputDecoration(
                labelText: 'Container type (e.g. Dry Van, Reefer)',
              ),
              validator: state._required,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: state._approxWeightTons,
                    decoration: const InputDecoration(
                      labelText: 'Weight (tons, optional)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Container size',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
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
              decoration: const InputDecoration(
                labelText: 'Container size (e.g. 20ft, 40ft)',
              ),
              validator: state._required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: state._cargoDescription,
              decoration: const InputDecoration(
                labelText: 'Cargo description (optional)',
              ),
              maxLines: 2,
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.centered = false,
  });

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
        padding: EdgeInsets.symmetric(
          horizontal: centered ? 0 : 13,
          vertical: 8,
        ),
        alignment: centered ? Alignment.center : null,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.ctaBlue : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
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
        Text(
          'When and exactly where the truck should collect.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: state._pickWindowStart,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Preferred pickup date & time',
            ),
            child: Text(
              state._pickupWindowStart == null
                  ? 'Tap to choose'
                  : DateFormat(
                      'd MMM yyyy, HH:mm',
                    ).format(state._pickupWindowStart!.toLocal()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: state._budgetPrice,
          decoration: const InputDecoration(
            labelText: 'Your budget, TZS (optional)',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            return double.tryParse(value.trim()) == null
                ? 'Enter a number'
                : null;
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Shown to transporters so they can bid with your budget in mind — you can still accept any bid.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: state._customerNotes,
          decoration: const InputDecoration(
            labelText: 'Notes for companies (optional)',
          ),
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
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.ctaBluePressed,
                    height: 1.4,
                  ),
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
              (
                'Route',
                '${state._pickupAddress.text} → ${state._dropoffAddress.text}',
              ),
              (
                'Cargo',
                [
                  state._containerType.text,
                  state._containerSize.text,
                  if (state._approxWeightTons.text.trim().isNotEmpty)
                    '${state._approxWeightTons.text} t',
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              if (state._pickupWindowStart != null)
                (
                  'Pickup',
                  DateFormat(
                    'd MMM yyyy, HH:mm',
                  ).format(state._pickupWindowStart!.toLocal()),
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    color: AppColors.surfaceSubtle,
                    child: Text(
                      'SHIPMENT SUMMARY',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLabel,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              row.$1,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              row.$2,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
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
