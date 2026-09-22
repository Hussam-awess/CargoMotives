import '../../../core/network/api_client.dart';

/// One review as shown on a public profile — deliberately anonymous about
/// the rater (ProfileRepository docblock / PublicReviewResource on the
/// backend).
class ProfileReview {
  const ProfileReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.categoryRatings,
    required this.createdAt,
  });

  factory ProfileReview.fromJson(Map<String, dynamic> json) {
    return ProfileReview(
      id: json['id'] as int,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      categoryRatings: (json['category_ratings'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as int),
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;
  final int rating;
  final String? comment;
  final Map<String, int>? categoryRatings;
  final DateTime createdAt;
}

/// One row of a profile's "recent completed jobs" — always anonymized
/// about the counterparty, on both the customer and transporter profile
/// (Job::recentCompletedSummariesFor() on the backend).
class RecentCompletedJobSummary {
  const RecentCompletedJobSummary({
    required this.completedAt,
    required this.containerType,
    required this.route,
  });

  factory RecentCompletedJobSummary.fromJson(Map<String, dynamic> json) {
    return RecentCompletedJobSummary(
      completedAt: DateTime.parse(json['completed_at'] as String),
      containerType: json['container_type'] as String,
      route: json['route'] as String,
    );
  }

  final DateTime completedAt;
  final String containerType;
  final String route;
}

/// A customer's public profile (CustomerProfileResource).
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.companyName,
    required this.companyLogoUrl,
    required this.avatarUrl,
    required this.memberSince,
    required this.averageRating,
    required this.ratingCount,
    required this.completedJobsCount,
    required this.cancelledJobsCount,
    required this.recentCompletedJobs,
    required this.recentReviews,
    this.isFollowing,
    this.isFeatured = false,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as int,
      fullName: json['full_name'] as String?,
      companyName: json['company_name'] as String?,
      companyLogoUrl: json['company_logo_url'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      memberSince: DateTime.parse(json['member_since'] as String),
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int,
      completedJobsCount: json['completed_jobs_count'] as int,
      cancelledJobsCount: json['cancelled_jobs_count'] as int,
      recentCompletedJobs: (json['recent_completed_jobs'] as List)
          .map(
            (e) =>
                RecentCompletedJobSummary.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      recentReviews: (json['recent_reviews'] as List)
          .map((e) => ProfileReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      isFollowing: json['is_following'] as bool?,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }

  final int id;
  final String? fullName;
  final String? companyName;
  final String? companyLogoUrl;

  /// The customer's own personal photo (EditProfileScreen) — distinct
  /// from [companyLogoUrl] (an optional *business* identity most
  /// customers never set up). Use [pictureUrl] to pick whichever actually
  /// exists rather than reading either field directly.
  final String? avatarUrl;
  final DateTime memberSince;
  final double? averageRating;
  final int ratingCount;
  final int completedJobsCount;
  final int cancelledJobsCount;
  final List<RecentCompletedJobSummary> recentCompletedJobs;
  final List<ProfileReview> recentReviews;

  /// Only present when the viewer is a transporter company — absent
  /// (null) for any other viewer, per CustomerProfileResource.
  final bool? isFollowing;

  /// Cargo Motives Plus — a real, paid-for status, shown here the same
  /// way it already is elsewhere in-app (e.g. on this customer's own
  /// profile menu).
  final bool isFeatured;

  String get displayName => companyName ?? fullName ?? 'Customer';

  /// The business logo takes precedence when a customer has set one up;
  /// otherwise their personal avatar; null (initial-letter fallback in
  /// the UI) only when neither exists.
  String? get pictureUrl => companyLogoUrl ?? avatarUrl;
}

/// A transporter company's public profile (CompanyProfileResource) — no
/// [isFollowing]: only a customer can be followed.
class CompanyProfile {
  const CompanyProfile({
    required this.id,
    required this.companyName,
    required this.logoUrl,
    required this.ownerAvatarUrl,
    required this.verified,
    required this.location,
    required this.memberSince,
    required this.averageRating,
    required this.ratingCount,
    required this.completedJobsCount,
    required this.fleetSize,
    required this.gpsAvailable,
    required this.recentCompletedJobs,
    required this.recentReviews,
    this.isFeatured = false,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      id: json['id'] as int,
      companyName: json['company_name'] as String,
      logoUrl: json['logo_url'] as String?,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      verified: json['verified'] as bool,
      location: json['location'] as String?,
      memberSince: DateTime.parse(json['member_since'] as String),
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int,
      completedJobsCount: json['completed_jobs_count'] as int,
      fleetSize: json['fleet_size'] as int,
      gpsAvailable: json['gps_available'] as bool,
      recentCompletedJobs: (json['recent_completed_jobs'] as List)
          .map(
            (e) =>
                RecentCompletedJobSummary.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      recentReviews: (json['recent_reviews'] as List)
          .map((e) => ProfileReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }

  final int id;
  final String companyName;
  final String? logoUrl;

  /// A company logo is optional at verification time — most never bother.
  /// Use [pictureUrl] to fall back to the owner's own personal photo
  /// rather than reading [logoUrl] directly.
  final String? ownerAvatarUrl;
  final bool verified;
  final String? location;
  final DateTime memberSince;
  final double? averageRating;
  final int ratingCount;
  final int completedJobsCount;
  final int fleetSize;
  final bool gpsAvailable;
  final List<RecentCompletedJobSummary> recentCompletedJobs;
  final List<ProfileReview> recentReviews;

  /// Cargo Motives Plus — see CustomerProfile.isFeatured.
  final bool isFeatured;

  String? get pictureUrl => logoUrl ?? ownerAvatarUrl;
}

/// Public profiles (Phase: public profiles) — reachable for any user id,
/// either role, by any authenticated viewer.
class ProfileRepository {
  ProfileRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CustomerProfile> customer(int customerId) async {
    final body = await _client.get('/profiles/customers/$customerId');
    return CustomerProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<ProfileReview>> customerReviews(
    int customerId, {
    int page = 1,
  }) async {
    final body = await _client.get(
      '/profiles/customers/$customerId/reviews?page=$page',
    );
    return (body['data'] as List)
        .map((e) => ProfileReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CompanyProfile> company(int companyId) async {
    final body = await _client.get('/profiles/companies/$companyId');
    return CompanyProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<ProfileReview>> companyReviews(
    int companyId, {
    int page = 1,
  }) async {
    final body = await _client.get(
      '/profiles/companies/$companyId/reviews?page=$page',
    );
    return (body['data'] as List)
        .map((e) => ProfileReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
