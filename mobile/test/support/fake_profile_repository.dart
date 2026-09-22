import 'package:cargo_motives/features/profiles/data/profile_repository.dart';

class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository({this.onCustomer, this.onCustomerReviews, this.onCompany, this.onCompanyReviews});

  final Future<CustomerProfile> Function(int customerId)? onCustomer;
  final Future<List<ProfileReview>> Function(int customerId, int page)? onCustomerReviews;
  final Future<CompanyProfile> Function(int companyId)? onCompany;
  final Future<List<ProfileReview>> Function(int companyId, int page)? onCompanyReviews;

  @override
  Future<CustomerProfile> customer(int customerId) => onCustomer?.call(customerId) ?? Future.error(StateError('customer not stubbed'));

  @override
  Future<List<ProfileReview>> customerReviews(int customerId, {int page = 1}) =>
      onCustomerReviews?.call(customerId, page) ?? Future.value(const []);

  @override
  Future<CompanyProfile> company(int companyId) => onCompany?.call(companyId) ?? Future.error(StateError('company not stubbed'));

  @override
  Future<List<ProfileReview>> companyReviews(int companyId, {int page = 1}) =>
      onCompanyReviews?.call(companyId, page) ?? Future.value(const []);
}
