import '../../../core/network/api_client.dart';
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
  Future<List<Job>> open({bool usePreferredRoutes = false}) =>
      _list(usePreferredRoutes ? '/company/jobs/open?use_preferred_routes=1' : '/company/jobs/open');

  Future<List<Job>> myBids() => _list('/company/jobs/my-bids');

  Future<List<Job>> active() => _list('/company/jobs/active');

  /// "Find a return load" (AppFlow §2.7, Featured-only) — other open jobs
  /// near where [jobId] just dropped off.
  Future<List<Job>> returnLoadSuggestions(int jobId) => _list('/company/jobs/$jobId/return-load-suggestions');

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

    return (body['data'] as List).map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }
}
