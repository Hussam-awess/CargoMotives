import 'package:cargo_motives/features/customer/data/featured_repository.dart';
import 'package:cargo_motives/features/customer/featured/featured_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_featured_repository.dart';

void main() {
  testWidgets('shows pricing for a non-featured customer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerFeaturedScreen(
          repository: FakeCustomerFeaturedRepository(
            onStatus: () async => const CustomerFeaturedStatus(isFeatured: false, featuredUntil: null, price: 20000, durationDays: 30),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to Featured'), findsOneWidget);
    expect(find.text('TZS 20000 for 30 days'), findsOneWidget);
  });

  testWidgets('shows Featured state once active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerFeaturedScreen(
          repository: FakeCustomerFeaturedRepository(
            onStatus: () async =>
                CustomerFeaturedStatus(isFeatured: true, featuredUntil: DateTime(2026, 10, 1), price: 20000, durationDays: 30),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're Featured"), findsOneWidget);
  });

  testWidgets('purchasing pushes a charge and confirms', (tester) async {
    Map<String, String>? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerFeaturedScreen(
          repository: FakeCustomerFeaturedRepository(
            onStatus: () async => const CustomerFeaturedStatus(isFeatured: false, featuredUntil: null, price: 20000, durationDays: 30),
            onPurchase: ({required provider, required phoneNumber}) async {
              captured = {'provider': provider, 'phoneNumber': phoneNumber};
              return const CustomerFeaturedPayment(status: 'pending_confirmation');
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

    expect(captured?['provider'], 'mpesa');
    expect(find.text('Check your phone to approve the payment.'), findsOneWidget);
  });
}
