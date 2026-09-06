import '../../../core/network/api_client.dart';

/// A company's commission balance snapshot (AppFlow §2.6/§2.7).
class CommissionSummary {
  const CommissionSummary({required this.outstandingBalance, required this.commissionStanding, required this.holdThreshold});

  factory CommissionSummary.fromJson(Map<String, dynamic> json) {
    return CommissionSummary(
      outstandingBalance: (json['outstanding_balance'] as num).toDouble(),
      commissionStanding: json['commission_standing'] as String,
      holdThreshold: (json['hold_threshold'] as num).toDouble(),
    );
  }

  final double outstandingBalance;
  final String commissionStanding; // good_standing | on_hold
  final double holdThreshold;

  bool get isOnHold => commissionStanding == 'on_hold';
}

/// One row of a company's commission transaction history (Backend Schema
/// §2.13) — the "Earnings ledger view."
class CommissionLedgerEntry {
  const CommissionLedgerEntry({
    required this.id,
    required this.entryType,
    required this.amount,
    required this.balanceAfter,
    required this.relatedJobId,
    required this.paymentId,
    required this.createdAt,
  });

  factory CommissionLedgerEntry.fromJson(Map<String, dynamic> json) {
    return CommissionLedgerEntry(
      id: json['id'] as int,
      entryType: json['entry_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      relatedJobId: json['related_job_id'] as int?,
      paymentId: json['payment_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;
  final String entryType; // charge | payment
  final double amount;
  final double balanceAfter;
  final int? relatedJobId;
  final int? paymentId;
  final DateTime createdAt;

  bool get isCharge => entryType == 'charge';
}

/// A mobile money payment attempt (Backend Schema §2.14) — only
/// commission paydowns in Phase 7.
class CommissionPayment {
  const CommissionPayment({required this.id, required this.amount, required this.status});

  factory CommissionPayment.fromJson(Map<String, dynamic> json) {
    return CommissionPayment(id: json['id'] as int, amount: (json['amount'] as num).toDouble(), status: json['status'] as String);
  }

  final int id;
  final double amount;
  final String status; // initiated | pending_confirmation | succeeded | failed

  bool get isPending => status == 'pending_confirmation';
}

/// Commission balance, its transaction history, and paying it down via
/// mobile money (AppFlow §2.6/§2.7).
class CommissionRepository {
  CommissionRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CommissionSummary> summary() async {
    final body = await _client.get('/company/commission/summary');

    return CommissionSummary.fromJson(body);
  }

  Future<List<CommissionLedgerEntry>> ledger() async {
    final body = await _client.get('/company/commission/ledger');

    return (body['data'] as List).map((e) => CommissionLedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CommissionPayment> payCommission({required double amount, required String provider, required String phoneNumber}) async {
    final body = await _client.post(
      '/company/commission/payments',
      data: {'amount': amount, 'mobile_money_provider': provider, 'phone_number': phoneNumber},
    );

    return CommissionPayment.fromJson(body['data'] as Map<String, dynamic>);
  }
}
