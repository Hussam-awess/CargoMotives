import '../../../core/network/api_client.dart';
import 'bid_repository.dart';
import 'job_repository.dart';

/// The Company side of job discovery — the three Jobs-home tabs (UI/UX
/// Brief §3): Open, My Bids, Active. Mirrors CompanyJobController on the
/// backend.
class CompanyJobRepository {
  CompanyJobRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// [usePreferredRoutes] applies a Featured company's saved route filter
  /// (AppFlow §2.7) — ignored server-side for a non-Featured company or
  /// one with no saved routes, so it's always safe to pass.
  Future<List<Job>> open({bool usePreferredRoutes = false}) => _list(
    usePreferredRoutes
        ? '/company/jobs/open?use_preferred_routes=1'
        : '/company/jobs/open',
  );

  Future<List<Job>> myBids() => _list('/company/jobs/my-bids');

  Future<List<Job>> active() => _list('/company/jobs/active');

  /// "Return Loads" tab (Plus Polish Batch Phase 4, Featured-only) — a
  /// persistent, browsable version of [returnLoadSuggestions], anchored on
  /// every one of this company's own relevant jobs at once rather than one
  /// specific just-delivered job.
  Future<List<Job>> returnLoads() => _list('/company/jobs/return-loads');

  /// "Find a return load" (AppFlow §2.7, Featured-only) — other open jobs
  /// near where [jobId] just dropped off.
  Future<List<Job>> returnLoadSuggestions(int jobId) =>
      _list('/company/jobs/$jobId/return-load-suggestions');

  /// One-tap claim on a matched return load (AppFlow §2.7, Featured-only)
  /// — no price negotiation, claimed at the job's own posted price.
  /// [fromJobId] is the just-delivered job the suggestion was shown
  /// against; the backend re-verifies the match itself rather than
  /// trusting this call.
  Future<Bid> claimReturnLoad(int jobId, {required int fromJobId}) async {
    final body = await _client.post(
      '/company/jobs/$jobId/claim-return-load',
      data: {'from_job_id': fromJobId},
    );

    return Bid.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Job> show(int jobId) async {
    final body = await _client.get('/company/jobs/$jobId');

    // is_assigned_to_viewer rides alongside `data` (JsonResource::additional
    // on the backend), not inside it — merge it in so Job.fromJson sees it.
    return Job.fromJson({
      ...body['data'] as Map<String, dynamic>,
      'is_assigned_to_viewer': body['is_assigned_to_viewer'],
    });
  }

  Future<List<Job>> _list(String path) async {
    final body = await _client.get(path);

    return (body['data'] as List)
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
