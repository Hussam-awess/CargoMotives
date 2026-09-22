import 'package:cargo_motives/features/profiles/customer_profile_screen.dart';
import 'package:cargo_motives/features/profiles/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_follow_repository.dart';
import '../../support/fake_profile_repository.dart';

CustomerProfile _profile({
  String? fullName = 'Amina Hassan',
  String? companyName,
  String? companyLogoUrl,
  String? avatarUrl,
  double? averageRating = 4.5,
  int ratingCount = 8,
  int completedJobsCount = 6,
  int cancelledJobsCount = 1,
  List<RecentCompletedJobSummary> recentCompletedJobs = const [],
  List<ProfileReview> recentReviews = const [],
  bool? isFollowing,
  bool isFeatured = false,
}) => CustomerProfile(
  id: 42,
  fullName: fullName,
  companyName: companyName,
  companyLogoUrl: companyLogoUrl,
  avatarUrl: avatarUrl,
  memberSince: DateTime(2025, 3, 1),
  averageRating: averageRating,
  ratingCount: ratingCount,
  completedJobsCount: completedJobsCount,
  cancelledJobsCount: cancelledJobsCount,
  recentCompletedJobs: recentCompletedJobs,
  recentReviews: recentReviews,
  isFollowing: isFollowing,
  isFeatured: isFeatured,
);

void main() {
  testWidgets('shows the customer\'s name, member-since date, and stats', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileScreen(
          customerId: 42,
          repository: FakeProfileRepository(
            onCustomer: (_) async => _profile(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(find.text('Member since March 2025'), findsOneWidget);
    expect(find.text('4.5 (8)'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
    'shows the initial letter when neither a business logo nor a personal avatar exists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async => _profile(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isNull);
      expect(find.text('A'), findsOneWidget);
    },
  );

  testWidgets('shows the personal avatar when no business logo was set up', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileScreen(
          customerId: 42,
          repository: FakeProfileRepository(
            onCustomer: (_) async =>
                _profile(avatarUrl: 'https://example.test/avatar.jpg'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The test binding stubs every HTTP request to 400 (no real network in
    // widget tests) — expected here, since this only checks which
    // NetworkImage the widget was built with, not that it actually
    // rendered. tester.takeException() acknowledges and clears it so the
    // test doesn't fail on an error that isn't what's under test.
    tester.takeException();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());
    expect(
      (avatar.backgroundImage as NetworkImage).url,
      'https://example.test/avatar.jpg',
    );
  });

  testWidgets(
    'prefers the business logo over the personal avatar when both exist',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async => _profile(
                companyLogoUrl: 'https://example.test/logo.jpg',
                avatarUrl: 'https://example.test/avatar.jpg',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(
        (avatar.backgroundImage as NetworkImage).url,
        'https://example.test/logo.jpg',
      );
    },
  );

  testWidgets(
    'prefers the company name over the full name when both are present',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async => _profile(companyName: 'Hassan Traders'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hassan Traders'), findsOneWidget);
      expect(find.text('Amina Hassan'), findsNothing);
    },
  );

  testWidgets(
    'shows "New" instead of a rating when the customer has none yet',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async =>
                  _profile(averageRating: null, ratingCount: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New'), findsOneWidget);
    },
  );

  testWidgets(
    'shows no Follow button when isFollowing is absent (non-transporter viewer)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async => _profile(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Follow'), findsNothing);
      expect(find.text('Following'), findsNothing);
    },
  );

  testWidgets(
    'shows a Follow button for a transporter viewer and follows on tap',
    (tester) async {
      int? followedId;
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async => _profile(isFollowing: false),
            ),
            followRepository: FakeFollowRepository(
              onFollow: (id) async {
                followedId = id;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Follow'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      expect(followedId, 42);
    },
  );

  testWidgets(
    'shows "No reviews yet." and no "See all" link when there are none',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async =>
                  _profile(averageRating: null, ratingCount: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reviews yet.'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
    },
  );

  testWidgets(
    'shows recent completed jobs anonymized to route/container/date only',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async => _profile(
                recentCompletedJobs: [
                  RecentCompletedJobSummary(
                    completedAt: DateTime(2026, 8, 20),
                    containerType: 'Dry Van',
                    route: 'Dar es Salaam → Mbeya',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Dar es Salaam → Mbeya'), findsOneWidget);
      expect(find.textContaining('Dry Van'), findsOneWidget);
      expect(find.text('20 Aug 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'a "See all" link opens the full reviews list when reviews exist',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerProfileScreen(
            customerId: 42,
            repository: FakeProfileRepository(
              onCustomer: (_) async => _profile(
                recentReviews: [
                  ProfileReview(
                    id: 1,
                    rating: 5,
                    comment: 'Great customer',
                    categoryRatings: null,
                    createdAt: DateTime(2026, 9, 1),
                  ),
                ],
              ),
              onCustomerReviews: (id, page) async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Great customer'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();

      expect(find.text('Reviews'), findsOneWidget);
    },
  );

  testWidgets('a load failure shows a retry option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileScreen(
          customerId: 42,
          repository: FakeProfileRepository(
            onCustomer: (_) async => throw StateError('boom'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this profile.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows a Plus badge for a Plus customer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileScreen(
          customerId: 42,
          repository: FakeProfileRepository(
            onCustomer: (_) async => _profile(isFeatured: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLUS'), findsOneWidget);
  });

  testWidgets('shows no Plus badge for a standard customer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileScreen(
          customerId: 42,
          repository: FakeProfileRepository(
            onCustomer: (_) async => _profile(isFeatured: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLUS'), findsNothing);
  });
}
