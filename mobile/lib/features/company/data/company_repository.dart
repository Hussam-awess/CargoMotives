import 'package:dio/dio.dart' show FormData, ListFormat, MultipartFile;
import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_client.dart';

/// A company's current verification state (Backend Schema §2.2's
/// verification_status), or null if nothing has been submitted yet.
class CompanyVerification {
  const CompanyVerification({
    required this.status,
    required this.rejectedReason,
    required this.companyName,
    this.registrationNumber,
    this.tin,
    this.physicalAddress,
    this.companyPhone,
    this.companyEmail,
    this.repFullName,
    this.repPosition,
  });

  factory CompanyVerification.fromJson(Map<String, dynamic> json) {
    return CompanyVerification(
      status: json['verification_status'] as String,
      rejectedReason: json['verification_rejected_reason'] as String?,
      companyName: json['company_name'] as String,
      registrationNumber: json['registration_number'] as String?,
      tin: json['tin'] as String?,
      physicalAddress: json['physical_address'] as String?,
      companyPhone: json['company_phone'] as String?,
      companyEmail: json['company_email'] as String?,
      repFullName: json['rep_full_name'] as String?,
      repPosition: json['rep_position'] as String?,
    );
  }

  final String status; // pending | approved | rejected | flagged_duplicate
  final String? rejectedReason;
  final String companyName;

  /// The company's own submitted details (Backend Schema §2.2) — present
  /// on every real GetStatus response (CompanyResource already returns
  /// them), just not previously read here. Used by the read-only "Company
  /// details & documents" settings row (Phase 10.18) rather than adding a
  /// second endpoint.
  final String? registrationNumber;
  final String? tin;
  final String? physicalAddress;
  final String? companyPhone;
  final String? companyEmail;
  final String? repFullName;
  final String? repPosition;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isUnderReview => status == 'pending' || status == 'flagged_duplicate';
}

/// The two-section verification form's fields (AppFlow §1), gathered as one
/// object so the submit call reads as a single intent rather than a long
/// positional parameter list.
///
/// Step 2's documents are the user's own explicit field list: a company
/// registration certificate and a TIN certificate as two distinct required
/// documents, plus an optional set of "other required transport/business
/// documents" — replacing the earlier single generic "business license"
/// upload.
class CompanyVerificationSubmission {
  CompanyVerificationSubmission({
    required this.companyName,
    required this.registrationNumber,
    required this.tin,
    required this.physicalAddress,
    required this.companyPhone,
    this.companyEmail,
    required this.registrationCertificate,
    required this.tinCertificate,
    this.otherDocuments = const [],
    required this.repFullName,
    required this.repPosition,
    required this.repNationalIdNumber,
    required this.repIdDocument,
  });

  final String companyName;
  final String registrationNumber;
  final String tin;
  final String physicalAddress;
  final String companyPhone;
  final String? companyEmail;
  final PlatformFile registrationCertificate;
  final PlatformFile tinCertificate;
  final List<PlatformFile> otherDocuments;

  final String repFullName;
  final String repPosition;
  final String repNationalIdNumber;
  final PlatformFile repIdDocument;
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

    return data == null ? null : CompanyVerification.fromJson(data as Map<String, dynamic>);
  }

  Future<CompanyVerification> submit(CompanyVerificationSubmission submission) async {
    final otherDocuments = await Future.wait(submission.otherDocuments.map(_toMultipart));

    final formData = FormData.fromMap({
      'company_name': submission.companyName,
      'registration_number': submission.registrationNumber,
      'tin': submission.tin,
      'physical_address': submission.physicalAddress,
      'company_phone': submission.companyPhone,
      if (submission.companyEmail != null && submission.companyEmail!.isNotEmpty) 'company_email': submission.companyEmail,
      'registration_certificate': await _toMultipart(submission.registrationCertificate),
      'tin_certificate': await _toMultipart(submission.tinCertificate),
      if (otherDocuments.isNotEmpty) 'other_documents': otherDocuments,
      'rep_full_name': submission.repFullName,
      'rep_position': submission.repPosition,
      'rep_national_id_number': submission.repNationalIdNumber,
      'rep_id_document': await _toMultipart(submission.repIdDocument),
      // Dio's default ListFormat.multi only brackets a list entry when the
      // entry is a Map/List — a bare List<MultipartFile> like
      // other_documents needs multiCompatible or every file lands under
      // the exact same non-bracketed field name and Laravel keeps only the
      // last one (Phase 3's TruckRepository regression).
    }, ListFormat.multiCompatible);

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
