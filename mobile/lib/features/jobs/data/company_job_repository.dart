import '../../../core/network/api_client.dart';
import 'job_repository.dart';

/// The Company side of job discovery — the three Jobs-home tabs (UI/UX
/// Brief §3): Open, My Bids, Active. Mirrors CompanyJobController on the
/// backend.
class CompanyJobRepository {
  CompanyJobRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Job>> open() => _list('/company/jobs/open');

  Future<List<Job>> myBids() => _list('/company/jobs/my-bids');

  Future<List<Job>> active() => _list('/company/jobs/active');

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
