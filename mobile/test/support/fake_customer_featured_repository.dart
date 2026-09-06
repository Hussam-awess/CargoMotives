import 'package:cargo_motives/features/customer/data/featured_repository.dart';

class FakeCustomerFeaturedRepository extends CustomerFeaturedRepository {
  FakeCustomerFeaturedRepository({this.onStatus, this.onPurchase});

  final Future<CustomerFeaturedStatus> Function()? onStatus;
  final Future<CustomerFeaturedPayment> Function({required String provider, required String phoneNumber})? onPurchase;

  @override
  Future<CustomerFeaturedStatus> status() =>
      onStatus?.call() ?? Future.value(const CustomerFeaturedStatus(isFeatured: false, featuredUntil: null, price: 20000, durationDays: 30));

  @override
  Future<CustomerFeaturedPayment> purchase({required String provider, required String phoneNumber}) {
    return onPurchase?.call(provider: provider, phoneNumber: phoneNumber) ??
        Future.value(const CustomerFeaturedPayment(status: 'pending_confirmation'));
  }
}
