import 'package:cargo_motives/features/company/data/follow_repository.dart';
import 'package:cargo_motives/features/company/followed_customers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_follow_repository.dart';

void main() {
  testWidgets('shows an empty state when following no one', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FollowedCustomersScreen(repository: FakeFollowRepository(onList: () async => [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're not following any customers yet."), findsOneWidget);
  });

  testWidgets('lists followed customers by their display name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FollowedCustomersScreen(
          repository: FakeFollowRepository(
            onList: () async => [
              const FollowedCustomer(id: 1, fullName: 'Amina Hassan', companyName: null, companyLogoUrl: null),
              const FollowedCustomer(id: 2, fullName: 'Juma Ally', companyName: 'Juma Logistics', companyLogoUrl: null),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina Hassan'), findsOneWidget);
    // Company name takes precedence over the personal name when present.
    expect(find.text('Juma Logistics'), findsOneWidget);
    expect(find.text('Juma Ally'), findsNothing);
  });

  testWidgets('unfollowing a customer removes them from the list', (tester) async {
    var callCount = 0;
    int? unfollowedId;

    await tester.pumpWidget(
      MaterialApp(
        home: FollowedCustomersScreen(
          repository: FakeFollowRepository(
            onList: () async {
              callCount++;
              return callCount == 1
                  ? [const FollowedCustomer(id: 1, fullName: 'Amina Hassan', companyName: null, companyLogoUrl: null)]
                  : [];
            },
            onUnfollow: (id) async {
              unfollowedId = id;
              return false;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina Hassan'), findsOneWidget);

    await tester.tap(find.text('Unfollow'));
    await tester.pumpAndSettle();

    expect(unfollowedId, 1);
    expect(find.text('Amina Hassan'), findsNothing);
    expect(find.text("You're not following any customers yet."), findsOneWidget);
  });
}
