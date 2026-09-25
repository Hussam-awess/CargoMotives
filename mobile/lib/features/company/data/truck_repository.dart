import 'package:dio/dio.dart' show FormData, ListFormat, MultipartFile;
import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_client.dart';

/// A registered truck (Backend Schema §2.3). GPS/current-assignment fields
/// exist on the model from Phase 3 but stay at their defaults (not shown
/// prominently in the UI) until Phase 6/4 respectively. last_known_* are
/// only ever populated on the Featured fleet-map endpoint (Phase 8) — the
/// ordinary Fleet list still doesn't need them.
class Truck {
  const Truck({
    required this.id,
    required this.registrationNumber,
    required this.makeModel,
    required this.vehicleType,
    required this.capacityTons,
    required this.photoUrls,
    required this.verificationStatus,
    required this.rejectedReason,
    required this.gpsStatus,
    required this.currentStatus,
    this.registrationCardUrl,
    this.insuranceUrl,
    this.lastKnownLat,
    this.lastKnownLng,
    this.lastKnownHeading,
    this.lastKnownAt,
    this.gpsDriverName,
    this.gpsOnline = false,
    this.gpsMoving = false,
    this.isGpsImported = false,
    this.gpsProvider,
  });

  factory Truck.fromJson(Map<String, dynamic> json) {
    return Truck(
      id: json['id'] as int,
      registrationNumber: json['registration_number'] as String,
      makeModel: json['make_model'] as String,
      vehicleType: json['vehicle_type'] as String,
      capacityTons: (json['capacity_tons'] as num).toDouble(),
      photoUrls: (json['photo_urls'] as List).cast<String>(),
      verificationStatus: json['verification_status'] as String,
      rejectedReason: json['verification_rejected_reason'] as String?,
      gpsStatus: json['gps_status'] as String,
      currentStatus: json['current_status'] as String,
      registrationCardUrl: json['registration_card_url'] as String?,
      insuranceUrl: json['insurance_url'] as String?,
      lastKnownLat: (json['last_known_lat'] as num?)?.toDouble(),
      lastKnownLng: (json['last_known_lng'] as num?)?.toDouble(),
      lastKnownHeading: (json['last_known_heading'] as num?)?.toDouble(),
      lastKnownAt: json['last_known_at'] == null
          ? null
          : DateTime.parse(json['last_known_at'] as String),
      gpsDriverName: json['gps_driver_name'] as String?,
      gpsOnline: json['gps_online'] as bool? ?? false,
      gpsMoving: json['gps_moving'] as bool? ?? false,
      isGpsImported: json['is_gps_imported'] as bool? ?? false,
      gpsProvider: json['gps_provider'] as String?,
    );
  }

  final int id;
  final String registrationNumber;
  final String makeModel;
  final String vehicleType;
  final double capacityTons;
  final List<String> photoUrls;
  // Truck review was removed, so this is always 'approved' today — the
  // server still sends it (and JobAssignmentService still gates on it) so
  // the review step can be reinstated without a schema change.
  final String verificationStatus;
  final String? rejectedReason;
  final String gpsStatus; // not_connected | connected | signal_lost
  final String currentStatus; // idle | on_job

  // Null when this truck has no such document yet — true of a bare
  // GPS-imported truck, which is created with no documents at all. The
  // edit form uses these to know what still has to be attached and what
  // is merely replaceable.
  final String? registrationCardUrl;
  final String? insuranceUrl;
  final double? lastKnownLat;
  final double? lastKnownLng;
  final double? lastKnownHeading;
  final DateTime? lastKnownAt;
  // Only ever populated for a provider that actually reports a driver
  // against the device itself (Tracksolid Pro today) — never a
  // substitute for a real job's assigned driver.
  final String? gpsDriverName;

  // True only when gps_status is 'connected' AND a position arrived
  // recently (same "signal lost" window used at the job level) — a stale
  // connection that hasn't reported in a while reads as offline here even
  // though the provider link itself is still nominally active.
  final bool gpsOnline;

  // Fleet map marker color: true (green) while actively moving or only
  // briefly slow; false (red) once stationary for 15+ minutes or
  // GPS-offline entirely — see the backend's Truck::isMoving() docblock.
  final bool gpsMoving;

  // Created directly from a GPS provider's device list rather than the
  // normal registration form — no real make/model/capacity/photos/
  // documents yet. Manage Fleet shows an "Imported from {gpsProvider}"
  // label and an "Add details" action instead of the usual chip set.
  final bool isGpsImported;

  // 'wialon' | 'traccar' | 'tracksolid_pro' | null — only set once this
  // truck is actually linked to a GPS connection.
  final String? gpsProvider;

  bool get isApproved => verificationStatus == 'approved';
  bool get isIdle => currentStatus == 'idle';

  // 'connected' or 'signal_lost' — either way a GPS device is still
  // linked to this truck, which blocks deletion until disconnected.
  bool get isGpsConnected => gpsStatus != 'not_connected';
}

/// The vehicle-info + documents fields for registering (or editing) a
/// truck (AppFlow §2.2).
///
/// Every document is nullable because editing an existing truck keeps
/// whatever is already on file unless a new file is actually attached —
/// correcting a capacity shouldn't mean re-uploading an insurance PDF.
/// Registering a new truck still has to supply all three; that's enforced
/// server-side (SubmitTruckRequest) and by the form itself.
class TruckSubmission {
  TruckSubmission({
    required this.registrationNumber,
    required this.makeModel,
    required this.vehicleType,
    required this.capacityTons,
    this.photos = const [],
    this.registrationCard,
    this.insurance,
    this.roadworthinessPermit,
  });

  final String registrationNumber;
  final String makeModel;
  final String vehicleType;
  final double capacityTons;
  final List<PlatformFile> photos;
  final PlatformFile? registrationCard;
  final PlatformFile? insurance;
  final PlatformFile? roadworthinessPermit;
}

class TruckRepository {
  TruckRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Truck>> list() async {
    final body = await _client.get('/company/trucks');

    return (body['data'] as List)
        .map((e) => Truck.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The fleet map (AppFlow §2.7) — every transporter's own GPS-connected
  /// trucks, not a Plus-only feature.
  Future<List<Truck>> map() async {
    final body = await _client.get('/company/fleet/map');

    return (body['data'] as List)
        .map((e) => Truck.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Truck> submit(TruckSubmission submission, {int? editTruckId}) async {
    final formData = FormData.fromMap(
      {
        'registration_number': submission.registrationNumber,
        'make_model': submission.makeModel,
        'vehicle_type': submission.vehicleType,
        'capacity_tons': submission.capacityTons.toString(),
        // Each document is sent only when one was actually picked —
        // omitting it tells the server to keep the existing file.
        if (submission.photos.isNotEmpty)
          'photos': await Future.wait(submission.photos.map(_toMultipart)),
        if (submission.registrationCard != null)
          'registration_card': await _toMultipart(submission.registrationCard!),
        if (submission.insurance != null)
          'insurance': await _toMultipart(submission.insurance!),
        if (submission.roadworthinessPermit != null)
          'roadworthiness_permit': await _toMultipart(
            submission.roadworthinessPermit!,
          ),
      },
      // Dio's default ListFormat.multi only brackets a list entry when the
      // entry is itself a Map/List — a MultipartFile isn't, so every photo
      // would be sent under the exact same bare `photos` field name, and
      // Laravel/PHP only keeps the LAST of several same-named non-bracketed
      // multipart parts (not an array). multiCompatible always brackets
      // (`photos[]`), which is what PHP's array parsing actually needs.
      ListFormat.multiCompatible,
    );

    final path = editTruckId == null
        ? '/company/trucks'
        : '/company/trucks/$editTruckId';
    final body = await _client.postForm(path, formData);

    return Truck.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Only allowed while the truck is idle and not GPS-connected
  /// (Truck.isIdle / Truck.isGpsConnected) — the backend re-checks both
  /// itself (a 422 either way), this is just the client-side gate that
  /// keeps the UI from offering it.
  Future<void> delete(int truckId) =>
      _client.delete('/company/trucks/$truckId');

  /// Disconnects just this one truck from GPS — distinct from a whole
  /// provider connection's own disconnect (GpsRepository), which affects
  /// every truck linked to it. This is what unblocks deleting a
  /// GPS-connected truck.
  Future<Truck> disconnectGps(int truckId) async {
    final body = await _client.post('/company/trucks/$truckId/disconnect-gps');

    return Truck.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    return MultipartFile.fromFile(file.path!, filename: file.name);
  }
}
