import 'package:cargo_motives/features/jobs/data/company_job_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';

class FakeCompanyJobRepository extends CompanyJobRepository {
  FakeCompanyJobRepository({this.onOpen, this.onMyBids, this.onActive, this.onShow});

  final Future<List<Job>> Function()? onOpen;
  final Future<List<Job>> Function()? onMyBids;
  final Future<List<Job>> Function()? onActive;
  final Future<Job> Function(int jobId)? onShow;

  @override
  Future<List<Job>> open() => onOpen?.call() ?? Future.value(const []);

  @override
  Future<List<Job>> myBids() => onMyBids?.call() ?? Future.value(const []);

  @override
  Future<List<Job>> active() => onActive?.call() ?? Future.value(const []);

  @override
  Future<Job> show(int jobId) => onShow?.call(jobId) ?? Future.error(StateError('show not stubbed'));
}
