import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';

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
}
