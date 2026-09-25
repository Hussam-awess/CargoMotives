import 'package:cargo_motives/features/company/data/company_repository.dart';

class FakeCompanyRepository extends CompanyRepository {
  FakeCompanyRepository({this.onGetStatus, this.onSubmit, this.onUpdateLocation});

  final Future<CompanyVerification?> Function()? onGetStatus;
  final Future<CompanyVerification> Function(
    CompanyVerificationSubmission submission,
  )?
  onSubmit;
  final Future<CompanyVerification> Function({required double lat, required double lng})?
  onUpdateLocation;

  @override
  Future<CompanyVerification?> getStatus() {
    return onGetStatus?.call() ?? Future.value(null);
  }

  @override
  Future<CompanyVerification> submit(CompanyVerificationSubmission submission) {
    return onSubmit?.call(submission) ??
        Future.value(
          const CompanyVerification(
            status: 'pending',
            rejectedReason: null,
            companyName: 'Test Co',
          ),
        );
  }

  @override
  Future<CompanyVerification> updateLocation({required double lat, required double lng}) {
    return onUpdateLocation?.call(lat: lat, lng: lng) ??
        Future.value(
          CompanyVerification(
            status: 'approved',
            rejectedReason: null,
            companyName: 'Test Co',
            physicalLat: lat,
            physicalLng: lng,
          ),
        );
  }
}
