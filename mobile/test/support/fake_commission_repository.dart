import 'package:cargo_motives/features/company/data/commission_repository.dart';

class FakeCommissionRepository extends CommissionRepository {
  FakeCommissionRepository({this.onSummary, this.onLedger, this.onPayCommission});

  final Future<CommissionSummary> Function()? onSummary;
  final Future<List<CommissionLedgerEntry>> Function()? onLedger;
  final Future<CommissionPayment> Function({required double amount, required String provider, required String phoneNumber})?
  onPayCommission;

  @override
  Future<CommissionSummary> summary() =>
      onSummary?.call() ??
      Future.value(const CommissionSummary(outstandingBalance: 0, commissionStanding: 'good_standing', holdThreshold: 500000));

  @override
  Future<List<CommissionLedgerEntry>> ledger() => onLedger?.call() ?? Future.value(const []);

  @override
  Future<CommissionPayment> payCommission({required double amount, required String provider, required String phoneNumber}) {
    return onPayCommission?.call(amount: amount, provider: provider, phoneNumber: phoneNumber) ??
        Future.value(CommissionPayment(id: 1, amount: amount, status: 'pending_confirmation'));
  }
}
