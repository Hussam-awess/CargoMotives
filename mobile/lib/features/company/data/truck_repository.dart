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
    this.lastKnownLat,
    this.lastKnownLng,
    this.lastKnownHeading,
    this.lastKnownAt,
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
      lastKnownLat: (json['last_known_lat'] as num?)?.toDouble(),
      lastKnownLng: (json['last_known_lng'] as num?)?.toDouble(),
      lastKnownHeading: (json['last_known_heading'] as num?)?.toDouble(),
      lastKnownAt: json['last_known_at'] == null ? null : DateTime.parse(json['last_known_at'] as String),
    );
  }

  final int id;
  final String registrationNumber;
  final String makeModel;
  final String vehicleType;
  final double capacityTons;
  final List<String> photoUrls;
  final String verificationStatus; // pending | approved | rejected
  final String? rejectedReason;
  final String gpsStatus; // not_connected | connected | signal_lost
  final String currentStatus; // idle | on_job
  final double? lastKnownLat;
  final double? lastKnownLng;
  final double? lastKnownHeading;
  final DateTime? lastKnownAt;

  bool get isRejected => verificationStatus == 'rejected';
  bool get isApproved => verificationStatus == 'approved';
  bool get isIdle => currentStatus == 'idle';
}

/// The vehicle-info + documents fields for registering (or resubmitting) a
/// truck (AppFlow §2.2).
class TruckSubmission {
  TruckSubmission({
    required this.registrationNumber,
    required this.makeModel,
    required this.vehicleType,
    required this.capacityTons,
    required this.photos,
    required this.registrationCard,
    required this.insurance,
    this.roadworthinessPermit,
  });

  final String registrationNumber;
  final String makeModel;
  final String vehicleType;
  final double capacityTons;
  final List<PlatformFile> photos;
  final PlatformFile registrationCard;
  final PlatformFile insurance;
  final PlatformFile? roadworthinessPermit;
}

class TruckRepository {
  TruckRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Truck>> list() async {
    final body = await _client.get('/company/trucks');

    return (body['data'] as List).map((e) => Truck.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The Featured "fleet map" (AppFlow §2.7) — Featured-only server-side;
  /// a non-Featured company gets a 403 (ApiException), which the screen
  /// shows as a friendly upgrade prompt rather than a generic error.
  Future<List<Truck>> map() async {
    final body = await _client.get('/company/fleet/map');

    return (body['data'] as List).map((e) => Truck.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Truck> submit(TruckSubmission submission, {int? resubmitTruckId}) async {
    final formData = FormData.fromMap(
      {
        'registration_number': submission.registrationNumber,
        'make_model': submission.makeModel,
        'vehicle_type': submission.vehicleType,
        'capacity_tons': submission.capacityTons.toString(),
        'photos': await Future.wait(submission.photos.map(_toMultipart)),
        'registration_card': await _toMultipart(submission.registrationCard),
        'insurance': await _toMultipart(submission.insurance),
        if (submission.roadworthinessPermit != null) 'roadworthiness_permit': await _toMultipart(submission.roadworthinessPermit!),
      },
      // Dio's default ListFormat.multi only brackets a list entry when the
      // entry is itself a Map/List — a MultipartFile isn't, so every photo
      // would be sent under the exact same bare `photos` field name, and
      // Laravel/PHP only keeps the LAST of several same-named non-bracketed
      // multipart parts (not an array). multiCompatible always brackets
      // (`photos[]`), which is what PHP's array parsing actually needs.
      ListFormat.multiCompatible,
    );

    final path = resubmitTruckId == null ? '/company/trucks' : '/company/trucks/$resubmitTruckId';
    final body = await _client.postForm(path, formData);

    return Truck.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Only allowed while the truck is idle (Truck.isIdle) — the backend
  /// re-checks this itself (current_status !== 'idle' throws a 422), this
  /// is just the client-side gate that keeps the UI from offering it.
  Future<void> delete(int truckId) => _client.delete('/company/trucks/$truckId');

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    return MultipartFile.fromFile(file.path!, filename: file.name);
  }
}
