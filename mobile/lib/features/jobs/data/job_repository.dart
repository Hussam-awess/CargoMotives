import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_client.dart';

/// A driver's delivery submission (Backend Schema §2.10), embedded on a
/// [Job] once its driver has submitted one via the Driver Link.
class ProofOfDelivery {
  const ProofOfDelivery({
    required this.photoUrls,
    required this.recipientName,
    required this.notes,
    required this.confirmedByCustomerAt,
    this.isSystemGenerated = false,
  });

  factory ProofOfDelivery.fromJson(Map<String, dynamic> json) {
    return ProofOfDelivery(
      photoUrls: (json['photo_urls'] as List).cast<String>(),
      recipientName: json['recipient_name'] as String?,
      notes: json['notes'] as String?,
      confirmedByCustomerAt: json['confirmed_by_customer_at'] == null
          ? null
          : DateTime.parse(json['confirmed_by_customer_at'] as String),
      isSystemGenerated: json['is_system_generated'] as bool? ?? false,
    );
  }

  final List<String> photoUrls;
  final String? recipientName;
  final String? notes;
  final DateTime? confirmedByCustomerAt;

  /// True when AutoCompleteStuckDeliveries (backend) submitted this on the
  /// transporter's behalf after the grace period passed, rather than a real
  /// driver/company submission — the UI shows a plain "Automatically
  /// completed" label instead of blank recipient/photos in that case.
  final bool isSystemGenerated;
}

/// A truck's position as of some moment (Backend Schema §2.3's
/// last_known_* fields) — the initial value on a freshly-fetched [Job]
/// (`last_known_location`), later kept current by JobLocationChannel
/// while the job screen is open (TRD §5.2).
class GpsLocation {
  const GpsLocation({
    required this.lat,
    required this.lng,
    required this.heading,
    required this.recordedAt,
    this.speedKmh,
  });

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

/// One truck+driver pair on a multi-truck job's roster (Bulk Cargo epic) —
/// for an ordinary job this list has at most one entry (the assigned
/// truck/driver), so every job can render one consistent "fleet" list
/// regardless of size.
class AssignedTruckSummary {
  const AssignedTruckSummary({
    required this.truckId,
    required this.registrationNumber,
    this.driverName,
  });

  factory AssignedTruckSummary.fromJson(Map<String, dynamic> json) {
    return AssignedTruckSummary(
      truckId: json['truck_id'] as int,
      registrationNumber: json['registration_number'] as String?,
      driverName: json['driver_name'] as String?,
    );
  }

  final int truckId;
  final String? registrationNumber;
  final String? driverName;
}

/// One company's committed slice of a multi-company bulk job (Multi-Company
/// Split Awards epic) — present only when a job ended up covered by 2+
/// companies' bids rather than a single one (see [Job.awards]'s docblock).
/// Each award is fully self-contained: its own roster, status, GPS, and
/// proof of delivery, independent of every other award on the same job.
class JobAward {
  const JobAward({
    required this.id,
    required this.companyId,
    this.companyName,
    required this.trucksOffered,
    required this.agreedPrice,
    required this.status,
    this.completedAt,
    this.assignedFleet = const [],
    this.assignedTrucksCount,
    this.gpsTrackingActive = false,
    this.gpsSignalStatus = 'not_applicable',
    this.lastKnownLocation,
    this.proofOfDelivery,
    this.driverInstructions,
  });

  factory JobAward.fromJson(Map<String, dynamic> json) {
    return JobAward(
      id: json['id'] as int,
      companyId: json['company_id'] as int,
      companyName: json['company_name'] as String?,
      trucksOffered: json['trucks_offered'] as int,
      agreedPrice: (json['agreed_price'] as num).toDouble(),
      status: json['status'] as String,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      assignedFleet: json['assigned_fleet'] == null
          ? const []
          : (json['assigned_fleet'] as List)
                .map(
                  (e) =>
                      AssignedTruckSummary.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
      assignedTrucksCount: json['assigned_trucks_count'] as int?,
      gpsTrackingActive: json['gps_tracking_active'] as bool? ?? false,
      gpsSignalStatus: json['gps_signal_status'] as String? ?? 'not_applicable',
      lastKnownLocation: json['last_known_location'] == null
          ? null
          : GpsLocation.fromJson(
              json['last_known_location'] as Map<String, dynamic>,
            ),
      proofOfDelivery: json['proof_of_delivery'] == null
          ? null
          : ProofOfDelivery.fromJson(
              json['proof_of_delivery'] as Map<String, dynamic>,
            ),
      driverInstructions: json['driver_instructions'] as String?,
    );
  }

  final int id;
  final int companyId;
  final String? companyName;
  final int trucksOffered;
  final double agreedPrice;

  /// assigned|en_route_pickup|picked_up|in_transit|delivered|completed —
  /// same vocabulary as [Job.status] but tracked entirely independently of
  /// it and of every other award on the same job.
  final String status;
  final DateTime? completedAt;
  final List<AssignedTruckSummary> assignedFleet;
  final int? assignedTrucksCount;
  final bool gpsTrackingActive;
  final String gpsSignalStatus;
  final GpsLocation? lastKnownLocation;
  final ProofOfDelivery? proofOfDelivery;

  /// A one-way note from this award's own company to its own driver(s) —
  /// independent of the job's [Job.driverInstructions] and of every other
  /// award on the same job.
  final String? driverInstructions;

  bool get isAwaitingDeliveryConfirmation => status == 'delivered';

  /// Mirrors Job.isAssignable — whether a truck/driver may still be
  /// assigned to THIS award's own roster, independent of the job's or any
  /// other award's status.
  bool get isAssignable => const [
    'assigned',
    'en_route_pickup',
    'picked_up',
    'in_transit',
  ].contains(status);
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
    this.trucksNeeded = 1,
    required this.approxWeightTons,
    required this.cargoDescription,
    required this.preferredPickupWindowStart,
    required this.customerNotes,
    this.budgetPrice,
    required this.agreedPrice,
    required this.currency,
    this.assignedCompanyId,
    required this.assignedCompanyName,
    required this.assignedTruckRegistration,
    required this.assignedDriverName,
    required this.proofOfDelivery,
    required this.bidsCount,
    this.isAssignedToViewer = false,
    this.gpsTrackingActive = false,
    this.gpsSignalStatus = 'not_applicable',
    this.lastKnownLocation,
    this.customerId,
    this.customerName,
    this.customerCompanyName,
    this.customerCompletedJobsCount,
    this.completedAt,
    this.isFollowingCustomer,
    this.reviewable,
    this.ratedByViewer,
    this.assignedTrucksCount,
    this.isEligible,
    this.assignedFleet = const [],
    this.remainingTrucksNeeded,
    this.awards = const [],
    this.biddingExpiresAt,
    this.biddingClosed,
    this.jobViewsCount,
    this.pickupPermitUrl,
    this.pickupPermitUploadedAt,
    this.dropoffPermitUrl,
    this.dropoffPermitUploadedAt,
    this.driverInstructions,
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
      trucksNeeded: json['trucks_needed'] as int? ?? 1,
      approxWeightTons: (json['approx_weight_tons'] as num?)?.toDouble(),
      cargoDescription: json['cargo_description'] as String?,
      preferredPickupWindowStart: DateTime.parse(
        json['preferred_pickup_window_start'] as String,
      ),
      customerNotes: json['customer_notes'] as String?,
      budgetPrice: (json['budget_price'] as num?)?.toDouble(),
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      currency: json['currency'] as String,
      assignedCompanyId: json['assigned_company_id'] as int?,
      assignedCompanyName: json['assigned_company_name'] as String?,
      assignedTruckRegistration: json['assigned_truck_registration'] as String?,
      assignedDriverName: json['assigned_driver_name'] as String?,
      proofOfDelivery: json['proof_of_delivery'] == null
          ? null
          : ProofOfDelivery.fromJson(
              json['proof_of_delivery'] as Map<String, dynamic>,
            ),
      bidsCount: json['bids_count'] as int?,
      isAssignedToViewer: json['is_assigned_to_viewer'] as bool? ?? false,
      gpsTrackingActive: json['gps_tracking_active'] as bool? ?? false,
      gpsSignalStatus: json['gps_signal_status'] as String? ?? 'not_applicable',
      lastKnownLocation: json['last_known_location'] == null
          ? null
          : GpsLocation.fromJson(
              json['last_known_location'] as Map<String, dynamic>,
            ),
      customerId: json['customer_id'] as int?,
      customerName: json['customer_name'] as String?,
      customerCompanyName: json['customer_company_name'] as String?,
      customerCompletedJobsCount: json['customer_completed_jobs_count'] as int?,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      isFollowingCustomer: json['is_following_customer'] as bool?,
      reviewable: json['reviewable'] as bool?,
      ratedByViewer: json['rated_by_viewer'] as bool?,
      assignedTrucksCount: json['assigned_trucks_count'] as int?,
      isEligible: json['is_eligible'] as bool?,
      assignedFleet: json['assigned_fleet'] == null
          ? const []
          : (json['assigned_fleet'] as List)
                .map(
                  (e) =>
                      AssignedTruckSummary.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
      remainingTrucksNeeded: json['remaining_trucks_needed'] as int?,
      awards: json['awards'] == null
          ? const []
          : (json['awards'] as List)
                .map((e) => JobAward.fromJson(e as Map<String, dynamic>))
                .toList(),
      biddingExpiresAt: json['bidding_expires_at'] == null
          ? null
          : DateTime.parse(json['bidding_expires_at'] as String),
      biddingClosed: json['bidding_closed'] as bool?,
      jobViewsCount: json['job_views_count'] as int?,
      pickupPermitUrl: json['pickup_permit_url'] as String?,
      pickupPermitUploadedAt: json['pickup_permit_uploaded_at'] == null
          ? null
          : DateTime.parse(json['pickup_permit_uploaded_at'] as String),
      dropoffPermitUrl: json['dropoff_permit_url'] as String?,
      dropoffPermitUploadedAt: json['dropoff_permit_uploaded_at'] == null
          ? null
          : DateTime.parse(json['dropoff_permit_uploaded_at'] as String),
      driverInstructions: json['driver_instructions'] as String?,
    );
  }

  final int id;
  final String
  status; // open|assigned|en_route_pickup|picked_up|in_transit|delivered|completed|cancelled
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String containerType;
  final String containerSize;

  /// How many trucks this job needs (Bulk Cargo epic) — 1 for an ordinary
  /// job, indistinguishable from every job posted before this field
  /// existed.
  final int trucksNeeded;
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
  final int? assignedCompanyId;
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
  final int? customerId;
  final String? customerName;
  final String? customerCompanyName;

  /// The posting customer's real completed-shipment count — a Company
  /// Plus trust signal (Phase 10.19), present only on
  /// CompanyJobRepository.open()'s response (CompanyJobController::open()
  /// is the only query that selects it).
  final int? customerCompletedJobsCount;

  /// The real moment this job was marked completed
  /// (JobController::confirmDelivery()) — never [preferredPickupWindowStart],
  /// which is only the originally requested schedule. Null until the job
  /// actually reaches 'completed'.
  final DateTime? completedAt;

  /// Whether the viewing transporter company already follows this job's
  /// customer (Phase: Follow system) — only present on a company-side job
  /// fetch (CompanyJobController); always null for the customer's own view
  /// of their job, since "following" is a company-only concept.
  final bool? isFollowingCustomer;

  /// Two-way ratings (Phase: ratings) — only present once the job is
  /// 'completed' and the viewer is a participant (JobResource). [reviewable]
  /// is true only while the *viewer's own* rating is still outstanding;
  /// [ratedByViewer] stays true forever once submitted, since a review is
  /// never editable.
  final bool? reviewable;
  final bool? ratedByViewer;

  /// The full truck+driver roster (Bulk Cargo epic) — one entry for an
  /// ordinary job, up to [trucksNeeded] entries for a multi-truck one.
  /// Empty until whoever's viewing has a reason to see it (whenLoaded-gated
  /// on the backend), not necessarily empty just because no truck exists.
  final List<AssignedTruckSummary> assignedFleet;

  /// How many trucks are currently on [assignedFleet] — present on list
  /// endpoints that select it without eager-loading the full roster.
  final int? assignedTrucksCount;

  /// Whether the viewing transporter company's verified fleet meets
  /// [trucksNeeded] (Bulk Cargo epic) — only present on a company-side job
  /// fetch; null for the customer's own view, since eligibility is a
  /// company-only concept. The job stays visible either way; this only
  /// decides whether the bid form or a "fleet too small" message renders.
  final bool? isEligible;

  /// How many trucks are still uncovered on this job (Multi-Company Split
  /// Awards epic) — only present on a company-side fetch; equal to
  /// [trucksNeeded] when no company has been awarded any part of it yet.
  final int? remainingTrucksNeeded;

  /// One entry per company that ended up covering only part of
  /// [trucksNeeded] — empty for every ordinary job and for a bulk job
  /// fully covered by a single company's bid. When this is non-empty, the
  /// job's own legacy [assignedCompanyName]/[assignedFleet]/GPS/proof-of-
  /// delivery fields are meaningless (there's no single "the" company) and
  /// the UI must render per-award instead.
  final List<JobAward> awards;

  /// The customer-chosen deadline for new bids (Bidding Deadline epic) —
  /// null for every job posted before this feature existed, or one that
  /// (structurally can't, since it's always required now) never got one;
  /// null means "no deadline," i.e. today's indefinite-until-accepted
  /// behavior.
  final DateTime? biddingExpiresAt;

  /// Computed server-side (Job::isBiddingClosed()), never derived here —
  /// avoids this device's own clock drift disagreeing with the backend
  /// about whether the deadline has actually passed. Null exactly when
  /// [biddingExpiresAt] is null.
  final bool? biddingClosed;

  /// Cargo Motives Plus benefit: how many distinct transporter companies
  /// have opened this job's detail — only ever present on the customer's
  /// own fetch of their own job (JobController::index()/show() are the
  /// only queries that select it). Whether to actually render it is a
  /// mobile-side decision gated on the *viewing customer's own*
  /// is_featured status (UserProfile.isFeatured), not this field's mere
  /// presence — a non-Plus customer's job still carries a real count, the
  /// UI just doesn't show it to them.
  final int? jobViewsCount;

  /// Cargo-authority checkpoint permits (customer-uploaded, job-level even
  /// for a split-award job — see the backend permit migrations' docblocks).
  /// The pickup one is informational only; the drop-off one is a hard
  /// blocker on ending the job (JobAssignmentController/
  /// DriverLinkPageController's submitProofOfDelivery()).
  final String? pickupPermitUrl;
  final DateTime? pickupPermitUploadedAt;
  final String? dropoffPermitUrl;
  final DateTime? dropoffPermitUploadedAt;

  /// A one-way note from the company to the driver(s) currently on this
  /// job (JobAssignmentController::updateInstructions()) — null for a
  /// split-award job, whose own copy lives on each [JobAward] instead.
  final String? driverInstructions;

  bool get isOpen => status == 'open';

  bool get isMultiTruck => trucksNeeded > 1;

  /// Gated on ANY award existing, not "2+" — the very first company
  /// awarded on a still-partially-open job already has nothing meaningful
  /// in the legacy single-company fields, so it needs the split-award UI
  /// immediately, not only once a second company joins.
  bool get isSplitAcrossCompanies => awards.isNotEmpty;

  /// Whether a truck/driver may still be assigned (or reassigned) to this
  /// job (AppFlow §2.5) — mirrors JobAssignmentService::ASSIGNABLE_STATUSES
  /// on the backend. Company-side callers must also check
  /// [isAssignedToViewer] before showing assignment actions.
  bool get isAssignable => const [
    'assigned',
    'en_route_pickup',
    'picked_up',
    'in_transit',
  ].contains(status);

  bool get isAwaitingDeliveryConfirmation => status == 'delivered';

  /// A view of this job with its GPS/lead-truck fields substituted from
  /// one award (Multi-Company Split Awards epic) — lets LiveGpsTrackingScreen
  /// render an award's own live position without needing its own
  /// award-aware fork, since a Tier 3 job's own gps_tracking_active/
  /// assigned_truck_registration stay permanently unset.
  Job forAwardMapView(JobAward award) {
    final lead = award.assignedFleet.isNotEmpty
        ? award.assignedFleet.first
        : null;

    return Job(
      id: id,
      status: award.status,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffAddress: dropoffAddress,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      containerType: containerType,
      containerSize: containerSize,
      trucksNeeded: trucksNeeded,
      approxWeightTons: approxWeightTons,
      cargoDescription: cargoDescription,
      preferredPickupWindowStart: preferredPickupWindowStart,
      customerNotes: customerNotes,
      budgetPrice: budgetPrice,
      agreedPrice: award.agreedPrice,
      currency: currency,
      assignedCompanyName: assignedCompanyName,
      assignedTruckRegistration: lead?.registrationNumber,
      assignedDriverName: lead?.driverName,
      proofOfDelivery: award.proofOfDelivery,
      bidsCount: bidsCount,
      gpsTrackingActive: award.gpsTrackingActive,
      gpsSignalStatus: award.gpsSignalStatus,
      lastKnownLocation: award.lastKnownLocation,
    );
  }
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
    this.trucksNeeded = 1,
    this.approxWeightTons,
    this.cargoDescription,
    required this.preferredPickupWindowStart,
    this.customerNotes,
    this.budgetPrice,
    this.currency = 'TZS',
    required this.biddingExpiresAt,
  });

  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String containerType;
  final String containerSize;

  /// How many trucks this job needs (Bulk Cargo epic) — 1 for an ordinary
  /// job.
  final int trucksNeeded;
  final double? approxWeightTons;
  final String? cargoDescription;
  final DateTime preferredPickupWindowStart;
  final String? customerNotes;

  /// Optional — a customer who doesn't know a fair price can still post
  /// without one, same as the rest of this form's optional fields.
  final double? budgetPrice;

  /// 'TZS' or 'USD' — a denomination choice only, not a currency
  /// conversion (see users.preferred_currency's backend migration
  /// docblock). Set once at posting and never editable afterward
  /// (JobController::save() strips it from an edit request server-side).
  final String currency;

  /// When new bids stop being accepted (Bidding Deadline epic) — required,
  /// bounded server-side to config('bidding.min_days'/'max_days') out from
  /// now and always before [preferredPickupWindowStart].
  final DateTime biddingExpiresAt;

  Map<String, dynamic> toJson() => {
    'pickup_address': pickupAddress,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'dropoff_address': dropoffAddress,
    'dropoff_lat': dropoffLat,
    'dropoff_lng': dropoffLng,
    'container_type': containerType,
    'container_size': containerSize,
    'trucks_needed': trucksNeeded,
    if (approxWeightTons != null) 'approx_weight_tons': approxWeightTons,
    if (cargoDescription != null && cargoDescription!.isNotEmpty)
      'cargo_description': cargoDescription,
    // .toUtc() first is load-bearing, not defensive: showDatePicker/
    // showTimePicker build a naive local-clock DateTime (e.g. 12:57 in the
    // customer's own timezone), and plain .toIso8601String() on a
    // non-UTC DateTime omits any 'Z'/offset suffix — the backend (running
    // in UTC) would then parse those same wall-clock digits AS UTC,
    // silently shifting the real instant by the device's UTC offset. For
    // Bidding Deadline's tight day-count bounds (validated against the
    // server's own now()) that off-by-timezone-offset skew was enough to
    // trip "Bidding can close at most N day(s) from now" even when the
    // customer picked a value well inside the window.
    'preferred_pickup_window_start': preferredPickupWindowStart
        .toUtc()
        .toIso8601String(),
    if (customerNotes != null && customerNotes!.isNotEmpty)
      'customer_notes': customerNotes,
    if (budgetPrice != null) 'budget_price': budgetPrice,
    'currency': currency,
    'bidding_expires_at': biddingExpiresAt.toUtc().toIso8601String(),
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

    return (body['data'] as List)
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Job> show(int jobId) async {
    final body = await _client.get('/jobs/$jobId');

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Job> post(JobSubmission submission) async {
    final body = await _client.post('/jobs', data: submission.toJson());

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Only accepted by the backend while the job is still 'open'
  /// (JobController::assertEditable()) — editing the pickup/drop-off
  /// location auto-withdraws any pending bids on the job.
  Future<Job> update(int jobId, JobSubmission submission) async {
    final body = await _client.post('/jobs/$jobId', data: submission.toJson());

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Job> cancel(int jobId, {String? reason}) async {
    final body = await _client.post(
      '/jobs/$jobId/cancel',
      data: {if (reason != null) 'reason': reason},
    );

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
    return _client.post(
      '/jobs/$jobId/report-problem',
      data: {'reason': reason},
    );
  }

  /// Multi-Company Split Awards epic: confirms one company's own slice of
  /// a split job — the per-award equivalent of [confirmDelivery], used
  /// instead of it whenever [Job.isSplitAcrossCompanies] is true (there's
  /// no single "the" delivery to confirm at the job level).
  Future<Job> confirmAwardDelivery(int jobId, int awardId) async {
    final body = await _client.post(
      '/jobs/$jobId/awards/$awardId/confirm-delivery',
    );

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Cargo-authority checkpoint permits (informational for pickup, a hard
  /// blocker on ending the job for drop-off — see [Job.dropoffPermitUrl]).
  Future<Job> uploadPickupPermit(int jobId, PlatformFile document) async {
    final formData = FormData.fromMap({
      'document': await _toMultipart(document),
    });
    final body = await _client.postForm('/jobs/$jobId/pickup-permit', formData);

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Job> uploadDropoffPermit(int jobId, PlatformFile document) async {
    final formData = FormData.fromMap({
      'document': await _toMultipart(document),
    });
    final body = await _client.postForm(
      '/jobs/$jobId/dropoff-permit',
      formData,
    );

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    return MultipartFile.fromFile(file.path!, filename: file.name);
  }
}
