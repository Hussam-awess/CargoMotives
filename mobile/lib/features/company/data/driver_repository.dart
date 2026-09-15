import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_client.dart';

/// A driver roster entry (Backend Schema §2.4) — never an account (PRD §5).
class Driver {
  const Driver({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.licenseNumber,
    required this.photoUrl,
    required this.isActive,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      licenseNumber: json['license_number'] as String?,
      photoUrl: json['photo_url'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  final int id;
  final String fullName;
  final String phoneNumber;
  final String? licenseNumber;
  final String? photoUrl;
  final bool isActive;
}

class DriverRepository {
  DriverRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Driver>> list() async {
    final body = await _client.get('/company/drivers');

    return (body['data'] as List).map((e) => Driver.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Driver> save({
    int? driverId,
    required String fullName,
    required String phoneNumber,
    String? licenseNumber,
    PlatformFile? licensePhoto,
  }) async {
    final formData = FormData.fromMap({
      'full_name': fullName,
      'phone_number': phoneNumber,
      if (licenseNumber != null && licenseNumber.isNotEmpty) 'license_number': licenseNumber,
      if (licensePhoto != null) 'license_photo': await _toMultipart(licensePhoto),
    });

    final path = driverId == null ? '/company/drivers' : '/company/drivers/$driverId';
    final body = await _client.postForm(path, formData);

    return Driver.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Only allowed while the driver isn't currently on a trip — unlike
  /// Truck, a driver has no client-visible status field to gate this on
  /// beforehand, so the caller just attempts it and shows the backend's
  /// error (a 422 naming the 'driver' field) if it's rejected.
  Future<void> delete(int driverId) => _client.delete('/company/drivers/$driverId');

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    return MultipartFile.fromFile(file.path!, filename: file.name);
  }
}
