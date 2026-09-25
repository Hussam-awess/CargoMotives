import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:cargo_motives/shared/data/payment_repository.dart';
import 'package:cargo_motives/shared/payments/payment_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_payment_repository.dart';

Payment _payment({
  int id = 1,
  String purpose = 'featured_company',
  double amount = 5000,
  String? provider = 'M-Pesa',
  String status = 'succeeded',
  DateTime? createdAt,
}) {
  return Payment(
    id: id,
    purpose: purpose,
    amount: amount,
    mobileMoneyProvider: provider,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 9, 20),
  );
}

Widget _appUnder(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

void main() {
  testWidgets('shows real transactions from the repository, not fabricated ones', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        PaymentHistoryScreen(
          repository: FakePaymentRepository(
            onList: () async => [
              _payment(id: 1, amount: 5000, createdAt: DateTime(2026, 9, 20)),
              _payment(id: 2, amount: 12000, status: 'failed', createdAt: DateTime(2026, 8, 1)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cargo Motives Plus'), findsNWidgets(2));
    expect(find.textContaining('20 Sep 2026'), findsOneWidget);
    expect(find.textContaining('1 Aug 2026'), findsOneWidget);
    expect(find.textContaining('Failed'), findsOneWidget);
  });

  testWidgets('labels each payment purpose and status', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        PaymentHistoryScreen(
          repository: FakePaymentRepository(
            onList: () async => [
              _payment(id: 1, purpose: 'featured_company', status: 'succeeded'),
              _payment(id: 2, purpose: 'featured_customer', status: 'pending_confirmation'),
              _payment(id: 3, purpose: 'commission_payment', status: 'initiated'),
              _payment(id: 4, purpose: 'commission_payment', status: 'failed'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cargo Motives Plus'), findsNWidgets(2));
    expect(find.text('Commission payment'), findsNWidgets(2));
    expect(find.textContaining('· Paid'), findsOneWidget);
    expect(find.textContaining('· Pending'), findsOneWidget);
    expect(find.textContaining('· Initiated'), findsOneWidget);
    expect(find.textContaining('· Failed'), findsOneWidget);
  });

  testWidgets('shows the screen in Swahili when that is the app language', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        PaymentHistoryScreen(
          repository: FakePaymentRepository(
            onList: () async => [
              _payment(id: 1, purpose: 'featured_company', status: 'succeeded'),
              _payment(id: 2, purpose: 'commission_payment', status: 'pending_confirmation'),
              _payment(id: 3, purpose: 'commission_payment', status: 'initiated'),
              _payment(id: 4, purpose: 'featured_customer', status: 'failed'),
            ],
          ),
        ),
        locale: const Locale('sw'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Historia ya Malipo'), findsOneWidget);
    expect(find.text('Jumla iliyolipwa'), findsOneWidget);
    expect(find.text('Malipo ya hivi karibuni'), findsOneWidget);
    expect(find.text('Malipo'), findsOneWidget);
    expect(find.text('Njia kuu ya malipo'), findsOneWidget);
    expect(find.text('Badilisha'), findsOneWidget);
    expect(find.text('Miamala'), findsOneWidget);
    expect(find.text('Malipo ya kamisheni'), findsNWidgets(2));
    expect(find.textContaining('· Imelipwa'), findsOneWidget);
    expect(find.textContaining('· Inasubiri'), findsOneWidget);
    expect(find.textContaining('· Imeanzishwa'), findsOneWidget);
    expect(find.textContaining('· Imeshindwa'), findsOneWidget);
    expect(find.text('Payment History'), findsNothing);
  });

  testWidgets('the summary card totals only succeeded payments', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        PaymentHistoryScreen(
          repository: FakePaymentRepository(
            onList: () async => [
              _payment(id: 1, amount: 5000, status: 'succeeded'),
              _payment(id: 2, amount: 12000, status: 'failed'),
              _payment(id: 3, amount: 3000, status: 'succeeded'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Total paid = 5000 + 3000 = 8000, excluding the failed 12000 payment.
    expect(find.text('TZS 8,000'), findsOneWidget);
    // "Payments" stat counts only the succeeded ones (2), not all 3 rows.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no payments yet', (tester) async {
    await tester.pumpWidget(
      _appUnder(PaymentHistoryScreen(repository: FakePaymentRepository(onList: () async => []))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No payments yet.'), findsOneWidget);
    expect(find.text('TZS 0'), findsOneWidget);
  });

  testWidgets('shows a retry option when loading fails', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _appUnder(
        PaymentHistoryScreen(
          repository: FakePaymentRepository(
            onList: () async {
              attempts++;
              if (attempts == 1) throw Exception('network error');
              return [_payment()];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load payment history.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Cargo Motives Plus'), findsOneWidget);
  });
}
