import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:file_picker/file_picker.dart';

class FakeJobRepository extends JobRepository {
  FakeJobRepository({
    this.onList,
    this.onShow,
    this.onPost,
    this.onCancel,
    this.onPostQuotaRemaining,
    this.onConfirmDelivery,
    this.onConfirmAwardDelivery,
    this.onUploadPickupPermit,
    this.onUploadDropoffPermit,
  });

  final Future<List<Job>> Function()? onList;
  final Future<Job> Function(int jobId)? onShow;
  final Future<Job> Function(JobSubmission submission)? onPost;
  final Future<Job> Function(int jobId, {String? reason})? onCancel;
  final Future<int> Function()? onPostQuotaRemaining;
  final Future<Job> Function(int jobId)? onConfirmDelivery;
  final Future<Job> Function(int jobId, int awardId)? onConfirmAwardDelivery;
  final Future<Job> Function(int jobId, PlatformFile document)?
  onUploadPickupPermit;
  final Future<Job> Function(int jobId, PlatformFile document)?
  onUploadDropoffPermit;

  @override
  Future<List<Job>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<Job> show(int jobId) =>
      onShow?.call(jobId) ?? Future.value(_defaultJob(jobId));

  @override
  Future<Job> post(JobSubmission submission) =>
      onPost?.call(submission) ?? Future.value(_defaultJob(1));

  @override
  Future<Job> cancel(int jobId, {String? reason}) =>
      onCancel?.call(jobId, reason: reason) ?? Future.value(_defaultJob(jobId));

  @override
  Future<int> postQuotaRemaining() =>
      onPostQuotaRemaining?.call() ?? Future.value(5);

  @override
  Future<Job> confirmDelivery(int jobId) =>
      onConfirmDelivery?.call(jobId) ?? Future.value(_defaultJob(jobId));

  @override
  Future<Job> confirmAwardDelivery(int jobId, int awardId) =>
      onConfirmAwardDelivery?.call(jobId, awardId) ??
      Future.value(_defaultJob(jobId));

  @override
  Future<Job> uploadPickupPermit(int jobId, PlatformFile document) =>
      onUploadPickupPermit?.call(jobId, document) ??
      Future.value(_defaultJob(jobId));

  @override
  Future<Job> uploadDropoffPermit(int jobId, PlatformFile document) =>
      onUploadDropoffPermit?.call(jobId, document) ??
      Future.value(_defaultJob(jobId));
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
  assignedTruckRegistration: null,
  assignedDriverName: null,
  proofOfDelivery: null,
  bidsCount: 0,
);
