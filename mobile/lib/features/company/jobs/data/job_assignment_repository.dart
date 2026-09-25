import 'package:dio/dio.dart' show FormData, ListFormat, MultipartFile;
import 'package:file_picker/file_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../jobs/data/job_repository.dart' show Job;

/// The Driver Link issued when a truck + driver are assigned to a job
/// (Backend Schema §2.5) — a single-use, no-login token the driver opens
/// on their own phone browser. [url] is what the company shares (AppFlow
/// §2.5: "shows it in-app to re-share if needed"), regardless of whether
/// the SMS itself went out.
class DriverLink {
  const DriverLink({required this.url, required this.status, required this.expiresAt, required this.driverName});

  factory DriverLink.fromJson(Map<String, dynamic> json) {
    return DriverLink(
      url: json['url'] as String,
      status: json['status'] as String, // active|used|expired
      expiresAt: DateTime.parse(json['expires_at'] as String),
      driverName: json['driver_name'] as String?,
    );
  }

  final String url;
  final String status;
  final DateTime expiresAt;
  final String? driverName;
}

/// Assigning a truck + driver to a job the company has already won
/// (AppFlow §2.5). Separate from CompanyJobRepository (browsing/bidding)
/// since this is a distinct concern with its own backend controller.
class JobAssignmentRepository {
  JobAssignmentRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<DriverLink> assign({required int jobId, required int truckId, required int driverId}) async {
    final body = await _client.post('/company/jobs/$jobId/assign', data: {'truck_id': truckId, 'driver_id': driverId});

    return DriverLink.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// The job's current active link, if any — null (not an error) once
  /// none is active, so callers can render "no link yet" instead of an
  /// error state for what is a perfectly normal condition before a first
  /// assignment.
  ///
  /// [truckId] disambiguates which roster truck's link to fetch on a
  /// multi-truck job (Bulk Cargo epic), which can have several
  /// simultaneously active links; omitted, or on an ordinary job, this
  /// fetches the job's one active link exactly as before that epic.
  Future<DriverLink?> currentDriverLink(int jobId, {int? truckId}) async {
    try {
      final path = truckId != null ? '/company/jobs/$jobId/driver-link?truck_id=$truckId' : '/company/jobs/$jobId/driver-link';
      final body = await _client.get(path);

      return DriverLink.fromJson(body['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// The manual "end job" escape hatch for a job stuck at 'in_transit'
  /// because of an inaccurate GPS fix — lets the company submit proof of
  /// delivery itself, from its own app, instead of needing the driver to
  /// visit the separate Driver Link page. Reuses that same driver link
  /// under the hood (backend), so it's indistinguishable afterward from a
  /// driver-submitted one.
  Future<Job> submitProofOfDelivery({
    required int jobId,
    required List<PlatformFile> photos,
    String? recipientName,
    String? notes,
  }) async {
    final formData = FormData.fromMap({
      'photos': await Future.wait(photos.map(_toMultipart)),
      if (recipientName != null && recipientName.isNotEmpty) 'recipient_name': recipientName,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      // Same fix as CompanyRepository's other_documents: a bare
      // List<MultipartFile> under Dio's default ListFormat.multi only
      // brackets a list entry when it's a Map/List, so every photo would
      // otherwise land under the same non-bracketed field name and Laravel
      // would keep only the last one.
    }, ListFormat.multiCompatible);

    final body = await _client.postForm('/company/jobs/$jobId/proof-of-delivery', formData);

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// A one-way note to the driver(s) currently on this job/award — see
  /// JobAssignmentController::updateInstructions()'s own docblock for why
  /// there's no reply channel (a driver has no account, no push).
  Future<Job> updateInstructions(int jobId, String instructions) async {
    final body = await _client.post('/company/jobs/$jobId/instructions', data: {'instructions': instructions});

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    return MultipartFile.fromFile(file.path!, filename: file.name);
  }
}
