import '../../../core/network/api_client.dart';

/// A customer as shown to a transporter company that follows them —
/// deliberately thin: no phone/email, contact stays through the in-app
/// Message feature (FollowedCustomerResource on the backend).
class FollowedCustomer {
  const FollowedCustomer({required this.id, required this.fullName, required this.companyName, required this.companyLogoUrl});

  factory FollowedCustomer.fromJson(Map<String, dynamic> json) {
    return FollowedCustomer(
      id: json['id'] as int,
      fullName: json['full_name'] as String?,
      companyName: json['company_name'] as String?,
      companyLogoUrl: json['company_logo_url'] as String?,
    );
  }

  final int id;
  final String? fullName;
  final String? companyName;
  final String? companyLogoUrl;

  String get displayName => companyName ?? fullName ?? 'Customer';
}

/// Follow/unfollow a customer (Phase: Follow system) — a transporter
/// company only gets "new job posted" notifications from customers it
/// follows (JobObserver::created()), instead of every customer on the
/// platform.
class FollowRepository {
  FollowRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<FollowedCustomer>> list() async {
    final body = await _client.get('/company/followed-customers');

    return (body['data'] as List).map((e) => FollowedCustomer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<bool> follow(int customerId) async {
    final body = await _client.post('/company/customers/$customerId/follow');

    return body['is_following'] as bool;
  }

  Future<bool> unfollow(int customerId) async {
    final body = await _client.delete('/company/customers/$customerId/follow');

    return body['is_following'] as bool;
  }
}
