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

    return Job.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<Job>> _list(String path) async {
    final body = await _client.get(path);

    return (body['data'] as List).map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }
}
