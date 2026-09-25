import 'package:cargo_motives/shared/data/payment_repository.dart';

class FakePaymentRepository extends PaymentRepository {
  FakePaymentRepository({super.isCompany = false, this.onList});

  final Future<List<Payment>> Function()? onList;

  @override
  Future<List<Payment>> list() => onList?.call() ?? Future.value(const []);
}
