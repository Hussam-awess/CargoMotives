import 'package:cargo_motives/features/jobs/data/company_job_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';

class FakeCompanyJobRepository extends CompanyJobRepository {
  FakeCompanyJobRepository({this.onOpen, this.onMyBids, this.onActive, this.onShow, this.onReturnLoadSuggestions});

  final Future<List<Job>> Function({bool usePreferredRoutes})? onOpen;
  final Future<List<Job>> Function()? onMyBids;
  final Future<List<Job>> Function()? onActive;
  final Future<Job> Function(int jobId)? onShow;
  final Future<List<Job>> Function(int jobId)? onReturnLoadSuggestions;

  @override
  Future<List<Job>> open({bool usePreferredRoutes = false}) =>
      onOpen?.call(usePreferredRoutes: usePreferredRoutes) ?? Future.value(const []);

  @override
  Future<List<Job>> myBids() => onMyBids?.call() ?? Future.value(const []);

  @override
  Future<List<Job>> active() => onActive?.call() ?? Future.value(const []);

  @override
  Future<Job> show(int jobId) => onShow?.call(jobId) ?? Future.error(StateError('show not stubbed'));

  @override
  Future<List<Job>> returnLoadSuggestions(int jobId) => onReturnLoadSuggestions?.call(jobId) ?? Future.value(const []);
}
