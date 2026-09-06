import '../../../core/network/api_client.dart';

/// A customer's Featured tier state (AppFlow §3.6: "explains the higher
/// daily post quota").
class CustomerFeaturedStatus {
  const CustomerFeaturedStatus({required this.isFeatured, required this.featuredUntil, required this.price, required this.durationDays});

  factory CustomerFeaturedStatus.fromJson(Map<String, dynamic> json) {
    return CustomerFeaturedStatus(
      isFeatured: json['is_featured'] as bool,
      featuredUntil: json['featured_until'] == null ? null : DateTime.parse(json['featured_until'] as String),
      price: (json['price'] as num).toDouble(),
      durationDays: json['duration_days'] as int,
    );
  }

  final bool isFeatured;
  final DateTime? featuredUntil;
  final double price;
  final int durationDays;
}

class CustomerFeaturedPayment {
  const CustomerFeaturedPayment({required this.status});

  factory CustomerFeaturedPayment.fromJson(Map<String, dynamic> json) => CustomerFeaturedPayment(status: json['status'] as String);

  final String status; // initiated | pending_confirmation | succeeded | failed

  bool get isPending => status == 'pending_confirmation';
}

/// Featured (Customer) — AppFlow §3.6.
class CustomerFeaturedRepository {
  CustomerFeaturedRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CustomerFeaturedStatus> status() async {
    final body = await _client.get('/featured/status');

    return CustomerFeaturedStatus.fromJson(body);
  }

  Future<CustomerFeaturedPayment> purchase({required String provider, required String phoneNumber}) async {
    final body = await _client.post('/featured/purchase', data: {'mobile_money_provider': provider, 'phone_number': phoneNumber});

    return CustomerFeaturedPayment.fromJson(body['data'] as Map<String, dynamic>);
  }
}
