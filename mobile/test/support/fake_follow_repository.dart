import 'package:cargo_motives/features/company/data/follow_repository.dart';

class FakeFollowRepository extends FollowRepository {
  FakeFollowRepository({this.onList, this.onFollow, this.onUnfollow});

  final Future<List<FollowedCustomer>> Function()? onList;
  final Future<bool> Function(int customerId)? onFollow;
  final Future<bool> Function(int customerId)? onUnfollow;

  @override
  Future<List<FollowedCustomer>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<bool> follow(int customerId) => onFollow?.call(customerId) ?? Future.value(true);

  @override
  Future<bool> unfollow(int customerId) => onUnfollow?.call(customerId) ?? Future.value(false);
}
