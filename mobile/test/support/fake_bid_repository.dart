import 'package:cargo_motives/features/jobs/data/bid_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';

class FakeBidRepository extends BidRepository {
  FakeBidRepository({this.onForJob, this.onPlace, this.onWithdraw, this.onAccept, this.onCompanyQuotaRemaining});

  final Future<List<Bid>> Function(int jobId)? onForJob;
  final Future<Bid> Function({required int jobId, required double price, DateTime? estimatedPickupTime, String? note})? onPlace;
  final Future<Bid> Function(int bidId)? onWithdraw;
  final Future<({Job job, Bid bid})> Function(int bidId)? onAccept;
  final Future<int> Function()? onCompanyQuotaRemaining;

  @override
  Future<List<Bid>> forJob(int jobId) => onForJob?.call(jobId) ?? Future.value(const []);

  @override
  Future<Bid> place({required int jobId, required double price, DateTime? estimatedPickupTime, String? note}) {
    return onPlace?.call(jobId: jobId, price: price, estimatedPickupTime: estimatedPickupTime, note: note) ??
        Future.value(_defaultBid(jobId: jobId, price: price));
  }

  @override
  Future<Bid> withdraw(int bidId) => onWithdraw?.call(bidId) ?? Future.value(_defaultBid(jobId: 1, price: 100000));

  @override
  Future<({Job job, Bid bid})> accept(int bidId) =>
      onAccept?.call(bidId) ?? Future.error(StateError('accept not stubbed'));

  @override
  Future<int> companyQuotaRemaining() => onCompanyQuotaRemaining?.call() ?? Future.value(5);
}

Bid _defaultBid({required int jobId, required double price}) => Bid(
  id: 1,
  jobId: jobId,
  price: price,
  estimatedPickupTime: null,
  note: null,
  status: 'pending',
  isPriority: false,
  company: const BidCompany(id: 1, name: 'ABC Logistics', verified: true, truckCount: 5, gpsAvailable: false, rating: 4.5, ratingCount: 10),
);
