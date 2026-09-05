import 'package:dio/dio.dart' show MultipartFile, FormData;
import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_client.dart';

/// A company's current verification state (Backend Schema §2.2's
/// verification_status), or null if nothing has been submitted yet.
class CompanyVerification {
  const CompanyVerification({
    required this.status,
    required this.rejectedReason,
    required this.companyName,
  });

  factory CompanyVerification.fromJson(Map<String, dynamic> json) {
    return CompanyVerification(
      status: json['verification_status'] as String,
      rejectedReason: json['verification_rejected_reason'] as String?,
      companyName: json['company_name'] as String,
    );
  }

  final String status; // pending | approved | rejected | flagged_duplicate
  final String? rejectedReason;
  final String companyName;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isUnderReview =>
      status == 'pending' || status == 'flagged_duplicate';
}

/// The two-section verification form's fields (AppFlow §1), gathered as one
/// object so the submit call reads as a single intent rather than a long
/// positional parameter list.
class CompanyVerificationSubmission {
  CompanyVerificationSubmission({
    required this.companyName,
    required this.registrationNumber,
    required this.tin,
    required this.physicalAddress,
    required this.companyPhone,
    this.companyEmail,
    required this.businessLicense,
    required this.repFullName,
    required this.repPosition,
    required this.repNationalIdNumber,
    required this.repIdDocument,
    required this.repSelfie,
  });

  final String companyName;
  final String registrationNumber;
  final String tin;
  final String physicalAddress;
  final String companyPhone;
  final String? companyEmail;
  final PlatformFile businessLicense;

  final String repFullName;
  final String repPosition;
  final String repNationalIdNumber;
  final PlatformFile repIdDocument;
  final PlatformFile repSelfie;
}

/// Wraps the Phase 2 company-verification endpoints. Reused by both the
/// verification form (submit) and the pending/rejected screens (getStatus,
/// polled with a manual "check again" rather than automatically, since
/// Admin review is a manual, unhurried process — TRD's WebSocket scoping
/// deliberately doesn't cover this).
class CompanyRepository {
  CompanyRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CompanyVerification?> getStatus() async {
    final body = await _client.get('/company/verification');
    final data = body['data'];

    return data == null
        ? null
        : CompanyVerification.fromJson(data as Map<String, dynamic>);
  }

  Future<CompanyVerification> submit(
    CompanyVerificationSubmission submission,
  ) async {
    final formData = FormData.fromMap({
      'company_name': submission.companyName,
      'registration_number': submission.registrationNumber,
      'tin': submission.tin,
      'physical_address': submission.physicalAddress,
      'company_phone': submission.companyPhone,
      if (submission.companyEmail != null &&
          submission.companyEmail!.isNotEmpty)
        'company_email': submission.companyEmail,
      'business_license': await _toMultipart(submission.businessLicense),
      'rep_full_name': submission.repFullName,
      'rep_position': submission.repPosition,
      'rep_national_id_number': submission.repNationalIdNumber,
      'rep_id_document': await _toMultipart(submission.repIdDocument),
      'rep_selfie': await _toMultipart(submission.repSelfie),
    });

    final body = await _client.postForm('/company/verification', formData);

    return CompanyVerification.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    // On web, PlatformFile only ever exposes `bytes` (no real filesystem
    // path); on other platforms `path` is set and bytes may not be loaded.
    // Handle both so this works identically across targets.
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    return MultipartFile.fromFile(file.path!, filename: file.name);
  }
}
