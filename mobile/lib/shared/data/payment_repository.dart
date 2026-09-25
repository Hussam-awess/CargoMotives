import '../../core/network/api_client.dart';

/// A single mobile-money payment attempt (Backend Schema §2.14) — shown in
/// Payment History for whichever role made it. Today the only purposes
/// ever actually created are `featured_company`/`featured_customer` (Plus
/// purchases); `commission_payment` exists on the backend enum but nothing
/// writes it yet. Display labels for [purpose]/[status] live in
/// PaymentHistoryScreen, where AppLocalizations is available.
class Payment {
  const Payment({
    required this.id,
    required this.purpose,
    required this.amount,
    required this.mobileMoneyProvider,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      purpose: json['purpose'] as String,
      amount: (json['amount'] as num).toDouble(),
      mobileMoneyProvider: json['mobile_money_provider'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;

  /// commission_payment | featured_company | featured_customer
  final String purpose;
  final double amount;
  final String? mobileMoneyProvider;

  /// initiated | pending_confirmation | succeeded | failed
  final String status;
  final DateTime createdAt;

  bool get succeeded => status == 'succeeded';
}

/// Payment history — shared between Customer and Company (a `Payment`
/// belongs to whichever role's own User row made it, identically either
/// way). [isCompany] just picks which of the two identical backend routes
/// to call.
class PaymentRepository {
  PaymentRepository({required this.isCompany, ApiClient? client}) : _client = client ?? ApiClient();

  final bool isCompany;
  final ApiClient _client;

  Future<List<Payment>> list() async {
    final body = await _client.get(isCompany ? '/company/payments' : '/payments');

    return (body['data'] as List)
        .map((e) => Payment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
