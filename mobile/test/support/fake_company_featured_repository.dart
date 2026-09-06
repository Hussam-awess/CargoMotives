import 'package:cargo_motives/features/company/data/featured_repository.dart';

class FakeCompanyFeaturedRepository extends CompanyFeaturedRepository {
  FakeCompanyFeaturedRepository({this.onStatus, this.onPurchase, this.onUpdatePreferredRoutes});

  final Future<CompanyFeaturedStatus> Function()? onStatus;
  final Future<FeaturedPayment> Function({required String provider, required String phoneNumber})? onPurchase;
  final Future<List<PreferredRoute>> Function(List<PreferredRoute> routes)? onUpdatePreferredRoutes;

  @override
  Future<CompanyFeaturedStatus> status() =>
      onStatus?.call() ??
      Future.value(const CompanyFeaturedStatus(isFeatured: false, featuredUntil: null, price: 50000, durationDays: 30, preferredRoutes: []));

  @override
  Future<FeaturedPayment> purchase({required String provider, required String phoneNumber}) {
    return onPurchase?.call(provider: provider, phoneNumber: phoneNumber) ?? Future.value(const FeaturedPayment(status: 'pending_confirmation'));
  }

  @override
  Future<List<PreferredRoute>> updatePreferredRoutes(List<PreferredRoute> routes) =>
      onUpdatePreferredRoutes?.call(routes) ?? Future.value(routes);
}
