import 'package:cargo_motives/shared/data/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    'id': 1,
    'purpose': 'featured_company',
    'amount': 5000,
    'mobile_money_provider': 'M-Pesa',
    'status': 'succeeded',
    'created_at': '2026-09-20T10:00:00Z',
  };

  group('Payment.fromJson', () {
    test('parses every field, including a whole-number amount', () {
      final payment = Payment.fromJson(baseJson());

      expect(payment.id, 1);
      expect(payment.purpose, 'featured_company');
      expect(payment.amount, 5000.0);
      expect(payment.mobileMoneyProvider, 'M-Pesa');
      expect(payment.status, 'succeeded');
      expect(payment.createdAt, DateTime.parse('2026-09-20T10:00:00Z'));
    });

    test('a null mobile money provider stays null', () {
      final payment = Payment.fromJson({...baseJson(), 'mobile_money_provider': null});

      expect(payment.mobileMoneyProvider, isNull);
    });
  });

  group('Payment.succeeded', () {
    test('true only for a succeeded status', () {
      expect(Payment.fromJson({...baseJson(), 'status': 'succeeded'}).succeeded, isTrue);
      expect(Payment.fromJson({...baseJson(), 'status': 'pending_confirmation'}).succeeded, isFalse);
      expect(Payment.fromJson({...baseJson(), 'status': 'initiated'}).succeeded, isFalse);
      expect(Payment.fromJson({...baseJson(), 'status': 'failed'}).succeeded, isFalse);
    });
  });
}
