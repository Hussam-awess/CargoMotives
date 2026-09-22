import '../../../core/network/api_client.dart';

/// A route a Featured company wants prioritized on the Open Jobs feed
/// (AppFlow §2.7) — plain origin/destination text, matched against a
/// job's pickup/dropoff address, not coordinates.
class PreferredRoute {
  const PreferredRoute({required this.origin, required this.destination});

  factory PreferredRoute.fromJson(Map<String, dynamic> json) {
    return PreferredRoute(
      origin: json['origin'] as String,
      destination: json['destination'] as String,
    );
  }

  final String origin;
  final String destination;

  Map<String, dynamic> toJson() => {
    'origin': origin,
    'destination': destination,
  };
}

/// A company's Featured tier state (AppFlow §2.7).
class CompanyFeaturedStatus {
  const CompanyFeaturedStatus({
    required this.isFeatured,
    required this.featuredUntil,
    required this.price,
    required this.durationDays,
    required this.preferredRoutes,
    this.homeRegion,
  });

  factory CompanyFeaturedStatus.fromJson(Map<String, dynamic> json) {
    return CompanyFeaturedStatus(
      isFeatured: json['is_featured'] as bool,
      featuredUntil: json['featured_until'] == null
          ? null
          : DateTime.parse(json['featured_until'] as String),
      price: (json['price'] as num).toDouble(),
      durationDays: json['duration_days'] as int,
      preferredRoutes: (json['preferred_routes'] as List)
          .map((e) => PreferredRoute.fromJson(e as Map<String, dynamic>))
          .toList(),
      homeRegion: json['home_region'] as String?,
    );
  }

  final bool isFeatured;
  final DateTime? featuredUntil;
  final double price;
  final int durationDays;
  final List<PreferredRoute> preferredRoutes;

  /// The company's base/return-to region (return-load matching) — a
  /// plain free-text region name, not a coordinate. Null when never set;
  /// return-load suggestions then rank by proximity alone.
  final String? homeRegion;
}

/// A Featured (or commission) mobile money payment attempt.
class FeaturedPayment {
  const FeaturedPayment({required this.status});

  factory FeaturedPayment.fromJson(Map<String, dynamic> json) =>
      FeaturedPayment(status: json['status'] as String);

  final String status; // initiated | pending_confirmation | succeeded | failed

  bool get isPending => status == 'pending_confirmation';
}

/// Featured (Company) — AppFlow §2.7: purchasing, and the one Featured-only
/// setting a company edits directly (preferred routes; priority bidding
/// and quotas are automatic once is_featured flips, nothing to configure).
class CompanyFeaturedRepository {
  CompanyFeaturedRepository({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CompanyFeaturedStatus> status() async {
    final body = await _client.get('/company/featured/status');

    return CompanyFeaturedStatus.fromJson(body);
  }

  Future<FeaturedPayment> purchase({
    required String provider,
    required String phoneNumber,
  }) async {
    final body = await _client.post(
      '/company/featured/purchase',
      data: {'mobile_money_provider': provider, 'phone_number': phoneNumber},
    );

    return FeaturedPayment.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<PreferredRoute>> updatePreferredRoutes(
    List<PreferredRoute> routes, {
    String? homeRegion,
  }) async {
    final body = await _client.post(
      '/company/featured/preferred-routes',
      data: {
        'routes': routes.map((r) => r.toJson()).toList(),
        'home_region': homeRegion,
      },
    );

    return (body['preferred_routes'] as List)
        .map((e) => PreferredRoute.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
