import 'package:cargo_motives/features/jobs/data/job_repository.dart';

class FakeJobRepository extends JobRepository {
  FakeJobRepository({this.onList, this.onShow, this.onPost, this.onCancel, this.onPostQuotaRemaining});

  final Future<List<Job>> Function()? onList;
  final Future<Job> Function(int jobId)? onShow;
  final Future<Job> Function(JobSubmission submission)? onPost;
  final Future<Job> Function(int jobId, {String? reason})? onCancel;
  final Future<int> Function()? onPostQuotaRemaining;

  @override
  Future<List<Job>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<Job> show(int jobId) => onShow?.call(jobId) ?? Future.value(_defaultJob(jobId));

  @override
  Future<Job> post(JobSubmission submission) => onPost?.call(submission) ?? Future.value(_defaultJob(1));

  @override
  Future<Job> cancel(int jobId, {String? reason}) => onCancel?.call(jobId, reason: reason) ?? Future.value(_defaultJob(jobId));

  @override
  Future<int> postQuotaRemaining() => onPostQuotaRemaining?.call() ?? Future.value(5);
}

Job _defaultJob(int id) => Job(
  id: id,
  status: 'open',
  pickupAddress: 'Kariakoo, Dar es Salaam',
  pickupLat: -6.8161,
  pickupLng: 39.2803,
  dropoffAddress: 'Mbezi Beach, Dar es Salaam',
  dropoffLat: -6.7,
  dropoffLng: 39.2,
  containerType: 'Dry Van',
  containerSize: '40ft',
  approxWeightTons: 12,
  cargoDescription: 'General cargo',
  preferredPickupWindowStart: DateTime(2026, 9, 10, 9),
  customerNotes: null,
  agreedPrice: null,
  currency: 'TZS',
  assignedCompanyName: null,
  bidsCount: 0,
);
