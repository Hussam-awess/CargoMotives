import 'package:cargo_motives/features/company/data/featured_repository.dart';
import 'package:cargo_motives/features/company/featured/featured_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_company_featured_repository.dart';

void main() {
  testWidgets('shows pricing and benefits for a non-featured company', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyFeaturedScreen(
          repository: FakeCompanyFeaturedRepository(
            onStatus: () async =>
                const CompanyFeaturedStatus(isFeatured: false, featuredUntil: null, price: 50000, durationDays: 30, preferredRoutes: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to Featured'), findsOneWidget);
    expect(find.text('TZS 50000 for 30 days'), findsOneWidget);
  });

  testWidgets('shows Featured state and preferred routes once active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyFeaturedScreen(
          repository: FakeCompanyFeaturedRepository(
            onStatus: () async => CompanyFeaturedStatus(
              isFeatured: true,
              featuredUntil: DateTime(2026, 10, 1),
              price: 50000,
              durationDays: 30,
              preferredRoutes: const [PreferredRoute(origin: 'Dar', destination: 'Arusha')],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're Featured"), findsOneWidget);
    expect(find.text('Dar → Arusha'), findsOneWidget);
  });

  testWidgets('purchasing pushes a charge and confirms', (tester) async {
    Map<String, String>? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyFeaturedScreen(
          repository: FakeCompanyFeaturedRepository(
            onStatus: () async =>
                const CompanyFeaturedStatus(isFeatured: false, featuredUntil: null, price: 50000, durationDays: 30, preferredRoutes: []),
            onPurchase: ({required provider, required phoneNumber}) async {
              captured = {'provider': provider, 'phoneNumber': phoneNumber};
              return const FeaturedPayment(status: 'pending_confirmation');
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
    expect(captured?['phoneNumber'], '0712345678');
    expect(find.text('Check your phone to approve the payment.'), findsOneWidget);
  });
}
