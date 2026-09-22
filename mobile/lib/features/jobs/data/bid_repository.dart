import '../../../core/network/api_client.dart';
import 'job_repository.dart';

/// A company's trust profile as shown on a bid (PRD §7.3): "ABC Logistics
/// ✓ · 28 trucks · Live GPS Available · ⭐4.8".
class BidCompany {
  const BidCompany({
    required this.id,
    required this.name,
    required this.verified,
    required this.truckCount,
    required this.gpsAvailable,
    required this.rating,
    required this.ratingCount,
  });

  factory BidCompany.fromJson(Map<String, dynamic> json) {
    return BidCompany(
      id: json['id'] as int,
      name: json['name'] as String,
      verified: json['verified'] as bool,
      truckCount: json['truck_count'] as int,
      gpsAvailable: json['gps_available'] as bool,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int,
    );
  }

  final int id;
  final String name;
  final bool verified;
  final int truckCount;
  final bool gpsAvailable;
  final double? rating;
  final int ratingCount;
}

class Bid {
  const Bid({
    required this.id,
    required this.jobId,
    required this.price,
    required this.estimatedPickupTime,
    required this.note,
    required this.status,
    required this.isPriority,
    required this.company,
    this.trucksOffered = 1,
    this.isReturnLoadClaim = false,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id'] as int,
      jobId: json['job_id'] as int,
      price: (json['price'] as num).toDouble(),
      estimatedPickupTime: json['estimated_pickup_time'] == null
          ? null
          : DateTime.parse(json['estimated_pickup_time'] as String),
      note: json['note'] as String?,
      status: json['status'] as String,
      isPriority: json['is_priority'] as bool,
      company: BidCompany.fromJson(json['company'] as Map<String, dynamic>),
      trucksOffered: json['trucks_offered'] as int? ?? 1,
      isReturnLoadClaim: json['is_return_load_claim'] as bool? ?? false,
    );
  }

  final int id;
  final int jobId;
  final double price;
  final DateTime? estimatedPickupTime;
  final String? note;
  final String status; // pending|accepted|rejected|withdrawn
  final bool isPriority;
  final BidCompany company;

  /// How many trucks this bid covers (Multi-Company Split Awards epic) —
  /// 1 for an ordinary bid.
  final int trucksOffered;

  /// A one-tap return-load match (CompanyJobRepository.claimReturnLoad()) —
  /// no price negotiation, claimed at the job's own posted price. The
  /// customer's bid list renders this distinctly rather than as a normal
  /// competitive offer, though accepting it works exactly the same way.
  final bool isReturnLoadClaim;
}

/// Bidding (PRD §7.4, TRD §6). Used by both roles: Customer accepts and
/// lists a job's bids; Company places/withdraws its own.
class BidRepository {
  BidRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Bid>> forJob(int jobId) async {
    final body = await _client.get('/jobs/$jobId/bids');

    return (body['data'] as List)
        .map((e) => Bid.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Bid> place({
    required int jobId,
    required double price,
    DateTime? estimatedPickupTime,
    String? note,
    int? trucksOffered,
  }) async {
    final body = await _client.post(
      '/company/jobs/$jobId/bids',
      data: {
        'price': price,
        // .toUtc() first — see JobSubmission.toJson()'s comment on the
        // same pattern; a naive local DateTime's ISO string has no
        // offset, so the (UTC) backend would otherwise parse these same
        // wall-clock digits as UTC and silently shift the real instant.
        if (estimatedPickupTime != null)
          'estimated_pickup_time': estimatedPickupTime
              .toUtc()
              .toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
        // Omitted on an ordinary job's bid form — the backend defaults it
        // to 1, matching every client that predates this field.
        if (trucksOffered != null) 'trucks_offered': trucksOffered,
      },
    );

    return Bid.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Bid> withdraw(int bidId) async {
    final body = await _client.post('/company/bids/$bidId/withdraw');

    return Bid.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<({Job job, Bid bid})> accept(int bidId) async {
    final body = await _client.post('/bids/$bidId/accept');

    return (
      job: Job.fromJson(body['job'] as Map<String, dynamic>),
      bid: Bid.fromJson(body['bid'] as Map<String, dynamic>),
    );
  }

  Future<int> companyQuotaRemaining() async {
    final body = await _client.get('/company/bid-quota');

    return body['remaining'] as int;
  }
}
