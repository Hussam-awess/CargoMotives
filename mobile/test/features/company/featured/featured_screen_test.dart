import 'package:cargo_motives/features/company/data/featured_repository.dart';
import 'package:cargo_motives/features/company/featured/featured_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_company_featured_repository.dart';

void main() {
  testWidgets('shows pricing and benefits for a non-featured company', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyFeaturedScreen(
          repository: FakeCompanyFeaturedRepository(
            onStatus: () async => const CompanyFeaturedStatus(
              isFeatured: false,
              featuredUntil: null,
              price: 50000,
              durationDays: 30,
              preferredRoutes: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('50000'), findsOneWidget);
    expect(find.text('/ 30 days'), findsOneWidget);
  });

  testWidgets('shows Featured state and preferred routes once active', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyFeaturedScreen(
          repository: FakeCompanyFeaturedRepository(
            onStatus: () async => CompanyFeaturedStatus(
              isFeatured: true,
              featuredUntil: DateTime(2026, 10, 1),
              price: 50000,
              durationDays: 30,
              preferredRoutes: const [
                PreferredRoute(origin: 'Dar', destination: 'Arusha'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("You're on Plus"), findsOneWidget);
    expect(find.text('Dar → Arusha'), findsOneWidget);
  });

  testWidgets('shows the saved home region, or a fallback message when unset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyFeaturedScreen(
          repository: FakeCompanyFeaturedRepository(
            onStatus: () async => const CompanyFeaturedStatus(
              isFeatured: true,
              featuredUntil: null,
              price: 50000,
              durationDays: 30,
              preferredRoutes: [],
              homeRegion: 'Mwanza',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mwanza'), findsOneWidget);
  });

  testWidgets('editing preferred routes saves the home region alongside them', (
    tester,
  ) async {
    List<PreferredRoute>? savedRoutes;
    String? savedHomeRegion;

    await tester.pumpWidget(
      MaterialApp(
        home: CompanyFeaturedScreen(
          repository: FakeCompanyFeaturedRepository(
            onStatus: () async => const CompanyFeaturedStatus(
              isFeatured: true,
              featuredUntil: null,
              price: 50000,
              durationDays: 30,
              preferredRoutes: [],
              homeRegion: null,
            ),
            onUpdatePreferredRoutes: (routes, {homeRegion}) async {
              savedRoutes = routes;
              savedHomeRegion = homeRegion;
              return routes;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit preferred routes'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Dar es Salaam'),
      'Mwanza',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedRoutes, isEmpty);
    expect(savedHomeRegion, 'Mwanza');
  });

  testWidgets('purchasing pushes a charge and confirms', (tester) async {
    Map<String, String>? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyFeaturedScreen(
          repository: FakeCompanyFeaturedRepository(
            onStatus: () async => const CompanyFeaturedStatus(
              isFeatured: false,
              featuredUntil: null,
              price: 50000,
              durationDays: 30,
              preferredRoutes: [],
            ),
            onPurchase: ({required provider, required phoneNumber}) async {
              captured = {'provider': provider, 'phoneNumber': phoneNumber};
              return const FeaturedPayment(status: 'pending_confirmation');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('GET PLUS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.textContaining('GET PLUS'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('GET PLUS'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile money phone number'),
      '0712345678',
    );
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(captured?['provider'], 'mpesa');
    expect(captured?['phoneNumber'], '0712345678');
    expect(
      find.text('Check your phone to approve the payment.'),
      findsOneWidget,
    );
  });
}
