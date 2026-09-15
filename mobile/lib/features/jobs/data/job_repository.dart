import '../../../core/network/api_client.dart';

/// A driver's delivery submission (Backend Schema §2.10), embedded on a
/// [Job] once its driver has submitted one via the Driver Link.
class ProofOfDelivery {
  const ProofOfDelivery({required this.photoUrls, required this.recipientName, required this.notes, required this.confirmedByCustomerAt});

  factory ProofOfDelivery.fromJson(Map<String, dynamic> json) {
    return ProofOfDelivery(
      photoUrls: (json['photo_urls'] as List).cast<String>(),
      recipientName: json['recipient_name'] as String?,
      notes: json['notes'] as String?,
      confirmedByCustomerAt: json['confirmed_by_customer_at'] == null ? null : DateTime.parse(json['confirmed_by_customer_at'] as String),
    );
  }

  final List<String> photoUrls;
  final String? recipientName;
  final String? notes;
  final DateTime? confirmedByCustomerAt;
}

/// A truck's position as of some moment (Backend Schema §2.3's
/// last_known_* fields) — the initial value on a freshly-fetched [Job]
/// (`last_known_location`), later kept current by JobLocationChannel
/// while the job screen is open (TRD §5.2).
class GpsLocation {
  const GpsLocation({required this.lat, required this.lng, required this.heading, required this.recordedAt, this.speedKmh});

  factory GpsLocation.fromJson(Map<String, dynamic> json) {
    return GpsLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
    );
  }

  final double lat;
  final double lng;
  final double? heading;
  final DateTime recordedAt;
  final double? speedKmh;
}

/// A shipment request (Backend Schema §2.7).
class Job {
  const Job({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.containerType,
    required this.containerSize,
    required this.approxWeightTons,
    required this.cargoDescription,
    required this.preferredPickupWindowStart,
    required this.customerNotes,
    this.budgetPrice,
    required this.agreedPrice,
    required this.currency,
    required this.assignedCompanyName,
    required this.assignedTruckRegistration,
    required this.assignedDriverName,
    required this.proofOfDelivery,
    required this.bidsCount,
    this.isAssignedToViewer = false,
    this.gpsTrackingActive = false,
    this.gpsSignalStatus = 'not_applicable',
    this.lastKnownLocation,
    this.customerName,
    this.customerCompanyName,
    this.customerCompletedJobsCount,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as int,
      status: json['status'] as String,
      pickupAddress: json['pickup_address'] as String,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
      dropoffAddress: json['dropoff_address'] as String,
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble(),
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble(),
      containerType: json['container_type'] as String,
      containerSize: json['container_size'] as String,
      approxWeightTons: (json['approx_weight_tons'] as num?)?.toDouble(),
      cargoDescription: json['cargo_description'] as String?,
      preferredPickupWindowStart: DateTime.parse(json['preferred_pickup_window_start'] as String),
      customerNotes: json['customer_notes'] as String?,
      budgetPrice: (json['budget_price'] as num?)?.toDouble(),
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      currency: json['currency'] as String,
      assignedCompanyName: json['assigned_company_name'] as String?,
      assignedTruckRegistration: json['assigned_truck_registration'] as String?,
      assignedDriverName: json['assigned_driver_name'] as String?,
      proofOfDelivery: json['proof_of_delivery'] == null
          ? null
          : ProofOfDelivery.fromJson(json['proof_of_delivery'] as Map<String, dynamic>),
      bidsCount: json['bids_count'] as int?,
      isAssignedToViewer: json['is_assigned_to_viewer'] as bool? ?? false,
      gpsTrackingActive: json['gps_tracking_active'] as bool? ?? false,
      gpsSignalStatus: json['gps_signal_status'] as String? ?? 'not_applicable',
      lastKnownLocation: json['last_known_location'] == null
          ? null
          : GpsLocation.fromJson(json['last_known_location'] as Map<String, dynamic>),
      customerName: json['customer_name'] as String?,
      customerCompanyName: json['customer_company_name'] as String?,
      customerCompletedJobsCount: json['customer_completed_jobs_count'] as int?,
    );
  }

  final int id;
  final String status; // open|assigned|en_route_pickup|picked_up|in_transit|delivered|completed|cancelled
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String containerType;
  final String containerSize;
  final double? approxWeightTons;
  final String? cargoDescription;
  final DateTime preferredPickupWindowStart;
  final String? customerNotes;

  /// The customer's own stated asking price — shown to a transporter
  /// company deciding what to bid. Distinct from [agreedPrice] (only ever
  /// set once a bid is accepted) and always optional.
  final double? budgetPrice;
  final double? agreedPrice;
  final String currency;
  final String? assignedCompanyName;
  final String? assignedTruckRegistration;
  final String? assignedDriverName;
  final ProofOfDelivery? proofOfDelivery;
  final int? bidsCount;

  /// Whether this job's assigned truck has GPS connected at all (TRD
  /// §5.3) — false means "GPS Tracking Not Available", never a loading
  /// state to wait out.
  final bool gpsTrackingActive;

  /// 'ok' | 'lost' | 'not_applicable' — only meaningful when
  /// [gpsTrackingActive] is true; 'lost' is a calm "signal unavailable"
  /// state, never a frozen/misleading marker (TRD §5.3).
  final String gpsSignalStatus;

  /// The truck's position as of the last ordinary REST fetch — shown
  /// immediately, then superseded by JobLocationChannel's live updates
  /// while the screen stays open.
  final GpsLocation? lastKnownLocation;

  /// Only meaningful on a company-side fetch (CompanyJobRepository.show) —
  /// a company can legitimately view a job it lost the bid on via "My
  /// Bids" even after it's moved past 'open', but only the company this
  /// job is actually assigned to may act on truck/driver assignment.
  /// Defaults to false (customer-side responses never set this key).
  final bool isAssignedToViewer;

  /// Only present on a company-side fetch of a single job
  /// (CompanyJobController::show() eager-loads the customer relation) —
  /// null on list endpoints and on the customer's own view of their job.
  final String? customerName;
  final String? customerCompanyName;

  /// The posting customer's real completed-shipment count — a Company
  /// Plus trust signal (Phase 10.19), present only on
  /// CompanyJobRepository.open()'s response (CompanyJobController::open()
  /// is the only query that selects it).
  final int? customerCompletedJobsCount;

  bool get isOpen => status == 'open';

  /// Whether a truck/driver may still be assigned (or reassigned) to this
  /// job (AppFlow §2.5) — mirrors JobAssignmentService::ASSIGNABLE_STATUSES
  /// on the backend. Company-side callers must also check
  /// [isAssignedToViewer] before showing assignment actions.
  bool get isAssignable => const ['assigned', 'en_route_pickup', 'picked_up', 'in_transit'].contains(status);

  bool get isAwaitingDeliveryConfirmation => status == 'delivered';
}

/// The Post a Job form's fields (AppFlow §3.2).
class JobSubmission {
  JobSubmission({
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.containerType,
    required this.containerSize,
    this.approxWeightTons,
    this.cargoDescription,
    required this.preferredPickupWindowStart,
    this.customerNotes,
    this.budgetPrice,
  });

  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String containerType;
  final String containerSize;
  final double? approxWeightTons;
  final String? cargoDescription;
  final DateTime preferredPickupWindowStart;
  final String? customerNotes;

  /// Optional — a customer who doesn't know a fair price can still post
  /// without one, same as the rest of this form's optional fields.
  final double? budgetPrice;

  Map<String, dynamic> toJson() => {
    'pickup_address': pickupAddress,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'dropoff_address': dropoffAddress,
    'dropoff_lat': dropoffLat,
    'dropoff_lng': dropoffLng,
    'container_type': containerType,
    'container_size': containerSize,
    if (approxWeightTons != null) 'approx_weight_tons': approxWeightTons,
    if (cargoDescription != null && cargoDescription!.isNotEmpty) 'cargo_description': cargoDescription,
    'preferred_pickup_window_start': preferredPickupWindowStart.toIso8601String(),
    if (customerNotes != null && customerNotes!.isNotEmpty) 'customer_notes': customerNotes,
    if (budgetPrice != null) 'budget_price': budgetPrice,
  };
}

/// The Customer side of job posting (AppFlow §3.2). Company-side job
/// discovery lives in CompanyJobRepository — split the same way the
/// backend splits JobController/CompanyJobController.
class JobRepository {
  JobRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Job>> list() async {
    final body = await _client.get('/jobs');

    return (body['data'] as List).map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Job> show(int jobId) async {
    final body = await _client.get('/jobs/$jobId');

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Job> post(JobSubmission submission) async {
    final body = await _client.post('/jobs', data: submission.toJson());

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Job> cancel(int jobId, {String? reason}) async {
    final body = await _client.post('/jobs/$jobId/cancel', data: {if (reason != null) 'reason': reason});

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<int> postQuotaRemaining() async {
    final body = await _client.get('/jobs/post-quota');

    return body['remaining'] as int;
  }

  /// Customer confirms receipt after a driver submits proof of delivery
  /// (AppFlow §3.5) — job moves from delivered to completed.
  Future<Job> confirmDelivery(int jobId) async {
    final body = await _client.post('/jobs/$jobId/confirm-delivery');

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// The alternative to confirmDelivery() once proof of delivery is in —
  /// raises a Dispute for Admin to review (AppFlow §3.5); does NOT change
  /// the job's own status.
  Future<void> reportProblem(int jobId, {required String reason}) {
    return _client.post('/jobs/$jobId/report-problem', data: {'reason': reason});
  }
}
