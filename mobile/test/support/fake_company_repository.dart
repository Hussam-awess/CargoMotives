import 'package:cargo_motives/features/company/data/company_repository.dart';

class FakeCompanyRepository extends CompanyRepository {
  FakeCompanyRepository({this.onGetStatus, this.onSubmit});

  final Future<CompanyVerification?> Function()? onGetStatus;
  final Future<CompanyVerification> Function(
    CompanyVerificationSubmission submission,
  )?
  onSubmit;

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
}
