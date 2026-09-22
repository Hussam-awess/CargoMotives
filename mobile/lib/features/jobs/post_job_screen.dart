import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../auth/data/auth_repository.dart';
import '../customer/addresses/saved_addresses_screen.dart'
    show SavedAddress, addSavedAddress, loadSavedAddresses;
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
/// The customer's saved address book is offered there too as quick-fill
/// chips, and "Save as address" below the map lets them add a new one from
/// whichever pin (pickup/drop-off) is currently active.
class PostJobScreen extends StatefulWidget {
  PostJobScreen({
    super.key,
    JobRepository? repository,
    AuthRepository? authRepository,
    this.prefillReturnFrom,
    this.prefillClone,
  }) : repository = repository ?? JobRepository(),
       authRepository = authRepository ?? AuthRepository(),
       assert(
         prefillReturnFrom == null || prefillClone == null,
         'Only one prefill source can be given.',
       );

  final JobRepository repository;
  final AuthRepository authRepository;

  /// Customer Plus benefit (Phase 10.19): "Post return shipment" on a
  /// completed job opens this screen with the route reversed (the
  /// original dropoff becomes the new pickup, and vice versa) and the
  /// same container type/size carried over — real data already on hand
  /// from that job, not fabricated. Weight/cargo description are left
  /// blank since the return cargo is genuinely different.
  final Job? prefillReturnFrom;

  /// Bidding Deadline epic: "Repost Job" / "Edit & Repost" once a job's
  /// bidding closed with zero bids — a straight, non-reversed prefill of
  /// every field (route, cargo, budget, the original bidding-deadline
  /// window as a starting point the customer adjusts before submitting),
  /// distinct from [prefillReturnFrom]'s reversed route.
  final Job? prefillClone;

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
  final _trucksNeeded = TextEditingController(text: '1');
  final _approxWeightTons = TextEditingController();
  final _cargoDescription = TextEditingController();
  final _customerNotes = TextEditingController();
  final _budgetPrice = TextEditingController();

  int _step = 0;
  DateTime? _pickupWindowStart;
  DateTime? _biddingExpiresAt;

  /// The customer's saved address book, offered as quick-fill chips on
  /// the route map — loaded once up front rather than only when Step 1
  /// first renders, so it's ready the instant it shows.
  List<SavedAddress> _savedAddresses = [];

  /// Which of the two pins (Pickup/Drop-off) the route map's toggle is
  /// currently on — mirrors RoutePickerMap's own internal mode via
  /// [MapPinMode] so "Save as address" below the map knows which point to
  /// save without RoutePickerMap needing to know anything about the
  /// address book itself.
  MapPinMode _activeMapMode = MapPinMode.pickup;

  /// Gates the saved-address free-tier cap the same way the Saved
  /// Addresses screen does — loaded alongside the preferred-currency
  /// profile fetch below.
  bool _isFeatured = false;

  /// A denomination choice only, set once at posting and never editable
  /// afterward (see users.preferred_currency's backend migration
  /// docblock — no conversion system exists behind this). Defaults to the
  /// customer's own Settings preference for a fresh post; a clone/return
  /// prefill instead carries over that original job's currency, matching
  /// every other prefilled field's "real data already on hand" reasoning.
  String _currency = 'TZS';

  /// Tracks which quick preset (if any) produced [_biddingExpiresAt] — a
  /// plain days-since-epoch comparison against DateTime.now() at build
  /// time would drift false within seconds of tapping a chip, since
  /// [_biddingExpiresAt] is a fixed point in time captured at tap-time.
  /// Null once a custom date/time is chosen instead.
  int? _biddingDeadlinePresetDays;
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
      _currency = returnFrom.currency;
    }

    final clone = widget.prefillClone;
    if (clone != null) {
      _pickupAddress.text = clone.pickupAddress;
      _pickupLat.text = clone.pickupLat?.toString() ?? '';
      _pickupLng.text = clone.pickupLng?.toString() ?? '';
      _dropoffAddress.text = clone.dropoffAddress;
      _dropoffLat.text = clone.dropoffLat?.toString() ?? '';
      _dropoffLng.text = clone.dropoffLng?.toString() ?? '';
      _containerType.text = clone.containerType;
      _containerSize.text = clone.containerSize;
      _trucksNeeded.text = '${clone.trucksNeeded}';
      _approxWeightTons.text = clone.approxWeightTons?.toString() ?? '';
      _cargoDescription.text = clone.cargoDescription ?? '';
      _customerNotes.text = clone.customerNotes ?? '';
      _budgetPrice.text = clone.budgetPrice?.toString() ?? '';
      _currency = clone.currency;
      _pickupWindowStart = clone.preferredPickupWindowStart;
      // The original deadline, carried over as a starting point — almost
      // certainly already in the past (that's why bidding closed), so the
      // customer still has to pick a fresh one; validation catches it
      // unchanged the same way it would for any stale value.
      _biddingExpiresAt = clone.biddingExpiresAt;
    }

    _loadProfileDefaults();
    _loadSavedAddresses();
  }

  /// Powers the currency picker's initial selection (skipped for a
  /// return/clone prefill, which already carries over the original job's
  /// own currency) and the saved-address free-tier cap check — a failed
  /// fetch just leaves the defaults in place rather than blocking the
  /// rest of this screen, same non-critical pattern used elsewhere for a
  /// Featured-status check.
  Future<void> _loadProfileDefaults() async {
    try {
      final profile = await widget.authRepository.me();
      if (!mounted) return;
      setState(() {
        _isFeatured = profile.isFeatured;
        if (widget.prefillReturnFrom == null && widget.prefillClone == null) {
          _currency = profile.preferredCurrency;
        }
      });
    } catch (_) {
      // Non-critical — see docblock above.
    }
  }

  /// Best-effort like every other non-critical fetch on this screen — a
  /// failed load just means the route map shows no saved-address chips.
  Future<void> _loadSavedAddresses() async {
    try {
      final addresses = await loadSavedAddresses();
      if (mounted) setState(() => _savedAddresses = addresses);
    } catch (_) {
      // Non-critical — see docblock above.
    }
  }

  void _setCurrency(String currency) => setState(() => _currency = currency);

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
      _trucksNeeded,
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
    if (pLat == null || pLng == null || dLat == null || dLng == null) {
      return null;
    }
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

  /// One of the quick "N days from now" chips (AppFlow spec's 5/6/7-day
  /// presets) — capped to stay before the pickup window when one's already
  /// chosen (a customer picking this before setting the pickup date just
  /// gets the plain N-day offset; [_biddingDeadlineError] catches it at
  /// submit time if that later turns out to land on/after the pickup date).
  void _pickQuickBiddingDeadline(int days) {
    var deadline = DateTime.now().add(Duration(days: days));
    final pickup = _pickupWindowStart;
    if (pickup != null && !deadline.isBefore(pickup)) {
      deadline = pickup.subtract(const Duration(hours: 1));
    }

    setState(() {
      _biddingExpiresAt = deadline;
      _biddingDeadlinePresetDays = days;
    });
  }

  Future<void> _pickCustomBiddingDeadline() async {
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
      _biddingExpiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _biddingDeadlinePresetDays = null;
    });
  }

  /// Client-side only — an immediate-feedback mirror of PostJobRequest's
  /// server-side rules (config('bidding.min_days'/'max_days'), always
  /// before the pickup window). The server re-enforces all of this
  /// regardless; this just avoids a round trip for the common mistakes.
  String? get _biddingDeadlineError {
    final deadline = _biddingExpiresAt;
    if (deadline == null) return 'Please choose when bidding closes.';
    if (deadline.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      return 'Bidding must stay open for at least 1 day.';
    }
    if (deadline.isAfter(DateTime.now().add(const Duration(days: 7)))) {
      return 'Bidding can close at most 7 days from now.';
    }
    final pickup = _pickupWindowStart;
    if (pickup != null && !deadline.isBefore(pickup)) {
      return 'Bidding must close before the pickup date.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickupWindowStart == null) {
      setState(
        () => _errorText = 'Please choose a preferred pickup date and time.',
      );
      return;
    }

    if (_biddingDeadlineError != null) {
      setState(() => _errorText = _biddingDeadlineError);
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
          trucksNeeded: int.parse(_trucksNeeded.text.trim()),
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
          budgetPrice: double.parse(_budgetPrice.text.trim()),
          currency: _currency,
          biddingExpiresAt: _biddingExpiresAt!,
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

  String? _requiredPrice(String? value) {
    if (_required(value) != null) return 'Required';

    return double.tryParse(value!.trim()) == null ? 'Enter a number' : null;
  }

  String? _requiredTruckCount(String? value) {
    if (_required(value) != null) return 'Required';

    final parsed = int.tryParse(value!.trim());
    return (parsed == null || parsed < 1) ? 'Enter at least 1' : null;
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

  void _setActiveMapMode(MapPinMode mode) =>
      setState(() => _activeMapMode = mode);

  /// "Add a saved address from the map" — saves whichever pin (pickup or
  /// drop-off) the map's toggle is currently on, using the coordinates
  /// and address text already filled into this step's own fields rather
  /// than re-deriving them, so a hand-edited address is respected too.
  Future<void> _saveActiveLocationAsAddress() async {
    final isPickup = _activeMapMode == MapPinMode.pickup;
    final latController = isPickup ? _pickupLat : _dropoffLat;
    final lngController = isPickup ? _pickupLng : _dropoffLng;
    final addressController = isPickup ? _pickupAddress : _dropoffAddress;

    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Set a ${isPickup ? 'pickup' : 'drop-off'} point on the map first.',
          ),
        ),
      );
      return;
    }

    final addressText = addressController.text.trim();
    final added = await addSavedAddress(
      context: context,
      isFeatured: _isFeatured,
      initialAddress: addressText.isEmpty ? null : addressText,
      lat: lat,
      lng: lng,
    );
    if (!added || !mounted) return;

    await _loadSavedAddresses();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Address saved.')));
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
          savedAddresses: state._savedAddresses,
          onModeChanged: state._setActiveMapMode,
          onPickupChanged: state._setPickupPoint,
          onDropoffChanged: state._setDropoffPoint,
          onRouteDistanceChanged: state._setRouteDistanceKm,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: state._saveActiveLocationAsAddress,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: Text(
              'Save ${state._activeMapMode == MapPinMode.pickup ? 'pickup' : 'drop-off'} as address',
            ),
          ),
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
              controller: state._trucksNeeded,
              decoration: const InputDecoration(
                labelText: 'Trucks needed',
                helperText: 'Leave as 1 for an ordinary single-truck job.',
              ),
              keyboardType: TextInputType.number,
              validator: state._requiredTruckCount,
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
        const SizedBox(height: 18),
        Text(
          'Bidding deadline',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose when bidding closes.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in [5, 6, 7])
              _Chip(
                label: '$days days',
                selected: state._biddingDeadlinePresetDays == days,
                onTap: () => state._pickQuickBiddingDeadline(days),
              ),
            _Chip(
              label: state._biddingExpiresAt == null
                  ? 'Custom date & time'
                  : DateFormat(
                      'd MMM, HH:mm',
                    ).format(state._biddingExpiresAt!.toLocal()),
              selected: false,
              onTap: state._pickCustomBiddingDeadline,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Currency',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 6),
        // A denomination choice only, set once here and never editable
        // afterward — see JobSubmission.currency's own docblock.
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'TZS', label: Text('TZS')),
            ButtonSegment(value: 'USD', label: Text('USD')),
          ],
          selected: {state._currency},
          onSelectionChanged: (selected) => state._setCurrency(selected.first),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: state._budgetPrice,
          decoration: InputDecoration(
            labelText: (int.tryParse(state._trucksNeeded.text.trim()) ?? 1) > 1
                ? 'Your budget, ${state._currency} (per truck)'
                : 'Your budget, ${state._currency}',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: state._requiredPrice,
        ),
        const SizedBox(height: 4),
        Text(
          // Multi-Company Split Awards epic: for a bulk job this is always
          // a per-truck rate, never a lump sum for the whole trucks_needed
          // count — otherwise a company bidding for only part of a big job
          // has no fair number to bid against. Transporters see the same
          // "(per truck)" wording on the bid screen.
          (int.tryParse(state._trucksNeeded.text.trim()) ?? 1) > 1
              ? 'Shown to transporters as your price per truck, not the total for all trucks — you can still accept any bid.'
              : 'Shown to transporters so they can bid with your budget in mind — you can still accept any bid.',
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
            state._trucksNeeded,
            state._approxWeightTons,
          ]),
          builder: (context, _) {
            final trucksNeeded =
                int.tryParse(state._trucksNeeded.text.trim()) ?? 1;
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
              if (trucksNeeded > 1) ('Trucks needed', '$trucksNeeded'),
              if (state._pickupWindowStart != null)
                (
                  'Pickup',
                  DateFormat(
                    'd MMM yyyy, HH:mm',
                  ).format(state._pickupWindowStart!.toLocal()),
                ),
              if (state._biddingExpiresAt != null)
                (
                  'Bidding closes',
                  DateFormat(
                    'd MMM yyyy, HH:mm',
                  ).format(state._biddingExpiresAt!.toLocal()),
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
