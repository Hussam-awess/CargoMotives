import 'package:cargo_motives/core/map/app_map.dart';
import 'package:cargo_motives/features/profiles/data/profile_repository.dart';
import 'package:cargo_motives/features/profiles/transporter_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_profile_repository.dart';

CompanyProfile _profile({
  bool verified = true,
  String? location = 'Kariakoo, Dar es Salaam',
  double? locationLat,
  double? locationLng,
  String? logoUrl,
  String? ownerAvatarUrl,
  double? averageRating = 4.8,
  int ratingCount = 20,
  int completedJobsCount = 15,
  int fleetSize = 5,
  bool gpsAvailable = true,
  List<RecentCompletedJobSummary> recentCompletedJobs = const [],
  List<ProfileReview> recentReviews = const [],
  bool isFeatured = false,
}) => CompanyProfile(
  id: 7,
  companyName: 'ABC Logistics',
  logoUrl: logoUrl,
  ownerAvatarUrl: ownerAvatarUrl,
  verified: verified,
  location: location,
  locationLat: locationLat,
  locationLng: locationLng,
  memberSince: DateTime(2024, 6, 1),
  averageRating: averageRating,
  ratingCount: ratingCount,
  completedJobsCount: completedJobsCount,
  fleetSize: fleetSize,
  gpsAvailable: gpsAvailable,
  recentCompletedJobs: recentCompletedJobs,
  recentReviews: recentReviews,
  isFeatured: isFeatured,
);

void main() {
  testWidgets(
    'shows the company\'s name, location, member-since date, and stats',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TransporterProfileScreen(
            companyId: 7,
            repository: FakeProfileRepository(
              onCompany: (_) async => _profile(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ABC Logistics'), findsOneWidget);
      expect(find.text('Kariakoo, Dar es Salaam'), findsOneWidget);
      expect(find.text('Member since June 2024'), findsOneWidget);
      expect(find.text('4.8 (20)'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the initial letter when neither a logo nor the owner\'s avatar exists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TransporterProfileScreen(
            companyId: 7,
            repository: FakeProfileRepository(
              onCompany: (_) async => _profile(),
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

  testWidgets(
    'falls back to the owner\'s personal avatar when the company has no logo',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TransporterProfileScreen(
            companyId: 7,
            repository: FakeProfileRepository(
              onCompany: (_) async =>
                  _profile(ownerAvatarUrl: 'https://example.test/avatar.jpg'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Expected — see the equivalent comment in customer_profile_screen_test.dart.
      tester.takeException();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(
        (avatar.backgroundImage as NetworkImage).url,
        'https://example.test/avatar.jpg',
      );
    },
  );

  testWidgets(
    'prefers the company\'s own logo over the owner\'s personal avatar',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TransporterProfileScreen(
            companyId: 7,
            repository: FakeProfileRepository(
              onCompany: (_) async => _profile(
                logoUrl: 'https://example.test/logo.jpg',
                ownerAvatarUrl: 'https://example.test/avatar.jpg',
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

  testWidgets('shows a verified badge only when approved', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async => _profile(verified: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('shows no verified badge when not approved', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async => _profile(verified: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.verified), findsNothing);
  });

  testWidgets('shows GPS connected when the fleet has a connected truck', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async => _profile(gpsAvailable: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GPS connected'), findsOneWidget);
  });

  testWidgets('shows no GPS connected when the fleet has none', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async => _profile(gpsAvailable: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No GPS connected'), findsOneWidget);
  });

  testWidgets(
    'never shows a cancelled-jobs stat (no real transporter cancellation action exists)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TransporterProfileScreen(
            companyId: 7,
            repository: FakeProfileRepository(
              onCompany: (_) async => _profile(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancelled'), findsNothing);
    },
  );

  testWidgets('shows "New" instead of a rating when the company has none yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async =>
                _profile(averageRating: null, ratingCount: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New'), findsOneWidget);
  });

  testWidgets(
    'a "See all" link opens the full reviews list when reviews exist',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TransporterProfileScreen(
            companyId: 7,
            repository: FakeProfileRepository(
              onCompany: (_) async => _profile(
                recentReviews: [
                  ProfileReview(
                    id: 1,
                    rating: 5,
                    comment: 'Excellent service',
                    categoryRatings: null,
                    createdAt: DateTime(2026, 9, 1),
                  ),
                ],
              ),
              onCompanyReviews: (id, page) async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excellent service'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();

      expect(find.text('Reviews'), findsOneWidget);
    },
  );

  testWidgets('a load failure shows a retry option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async => throw StateError('boom'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this profile.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows a Plus badge for a Plus company', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async => _profile(isFeatured: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLUS'), findsOneWidget);
  });

  testWidgets('shows no Plus badge for a standard company', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async => _profile(isFeatured: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLUS'), findsNothing);
  });

  testWidgets('shows a location map preview once the company has set a pin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(
            onCompany: (_) async => _profile(locationLat: -6.8161, locationLng: 39.2803),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location'), findsOneWidget);
    expect(find.byType(AppMap), findsOneWidget);
    expect(find.byType(AppMapPin), findsOneWidget);
  });

  testWidgets('shows no location map preview when the company has no pin set', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransporterProfileScreen(
          companyId: 7,
          repository: FakeProfileRepository(onCompany: (_) async => _profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location'), findsNothing);
    expect(find.byType(AppMap), findsNothing);
  });
}
