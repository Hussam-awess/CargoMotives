import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/company/data/commission_repository.dart';
import 'package:cargo_motives/features/company/earnings/earnings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_commission_repository.dart';

void main() {
  testWidgets('shows the outstanding balance and ledger history', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EarningsScreen(
          repository: FakeCommissionRepository(
            onSummary: () async => const CommissionSummary(outstandingBalance: 150000, commissionStanding: 'good_standing', holdThreshold: 500000),
            onLedger: () async => [
              CommissionLedgerEntry(id: 1, entryType: 'charge', amount: 200000, balanceAfter: 200000, relatedJobId: 5, paymentId: null, createdAt: DateTime(2026, 9, 10)),
              CommissionLedgerEntry(id: 2, entryType: 'payment', amount: 50000, balanceAfter: 150000, relatedJobId: null, paymentId: 1, createdAt: DateTime(2026, 9, 11)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TZS 150000'), findsOneWidget);
    expect(find.text('Commission charge'), findsOneWidget);
    expect(find.text('Pay via Mobile Money'), findsOneWidget);
    expect(find.text('Account on hold — pay your commission balance to resume bidding.'), findsNothing);
  });

  testWidgets('shows the on-hold banner when the company is on hold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EarningsScreen(
          repository: FakeCommissionRepository(
            onSummary: () async => const CommissionSummary(outstandingBalance: 600000, commissionStanding: 'on_hold', holdThreshold: 500000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('on hold'), findsWidgets);
  });

  testWidgets('the Pay button is disabled when nothing is owed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EarningsScreen(
          repository: FakeCommissionRepository(
            onSummary: () async => const CommissionSummary(outstandingBalance: 0, commissionStanding: 'good_standing', holdThreshold: 500000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Pay via Mobile Money'));
    expect(button.onPressed, isNull);
  });

  testWidgets('paying via mobile money submits the form and shows a confirmation', (tester) async {
    Map<String, dynamic>? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: EarningsScreen(
          repository: FakeCommissionRepository(
            onSummary: () async => const CommissionSummary(outstandingBalance: 50000, commissionStanding: 'good_standing', holdThreshold: 500000),
            onPayCommission: ({required amount, required provider, required phoneNumber}) async {
              captured = {'amount': amount, 'provider': provider, 'phoneNumber': phoneNumber};
              return CommissionPayment(id: 1, amount: amount, status: 'pending_confirmation');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay via Mobile Money'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Mobile money phone number'), '0712345678');
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(captured?['amount'], 50000.0);
    expect(captured?['phoneNumber'], '0712345678');
    expect(find.text('Check your phone to approve the payment.'), findsOneWidget);
  });

  testWidgets('a payment validation error is surfaced without closing the sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EarningsScreen(
          repository: FakeCommissionRepository(
            onSummary: () async => const CommissionSummary(outstandingBalance: 50000, commissionStanding: 'good_standing', holdThreshold: 500000),
            onPayCommission: ({required amount, required provider, required phoneNumber}) async =>
                throw ApiException('The amount may not be greater than 50000.', fieldErrors: {
                  'amount': ['The amount may not be greater than 50000.'],
                }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay via Mobile Money'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Mobile money phone number'), '0712345678');
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(find.text('The amount may not be greater than 50000.'), findsOneWidget);
  });
}
