import 'package:cargo_motives/features/company/company_home_tab.dart';
import 'package:cargo_motives/features/company/data/driver_repository.dart';
import 'package:cargo_motives/features/company/data/featured_repository.dart';
import 'package:cargo_motives/features/company/data/truck_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:cargo_motives/shared/widgets/plus_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_company_featured_repository.dart';
import '../../support/fake_company_job_repository.dart';
import '../../support/fake_driver_repository.dart';
import '../../support/fake_truck_repository.dart';

Widget _appUnder(Widget home) {
  return MaterialApp(
    home: home,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

Job _job({int id = 1, String status = 'open'}) {
  return Job(
    id: id,
    status: status,
    pickupAddress: 'Tanga',
    pickupLat: -5.07,
    pickupLng: 39.1,
    dropoffAddress: 'Dodoma',
    dropoffLat: -6.16,
    dropoffLng: 35.75,
    containerType: 'Flatbed',
    containerSize: '20ft',
    approxWeightTons: 18,
    cargoDescription: null,
    preferredPickupWindowStart: DateTime(2026, 9, 14, 8),
    customerNotes: null,
    agreedPrice: null,
    currency: 'TZS',
    assignedCompanyName: null,
    assignedTruckRegistration: 'T 123 ABC',
    assignedDriverName: 'Joseph Mwanga',
    proofOfDelivery: null,
    bidsCount: 5,
  );
}

void main() {
  testWidgets(
    'shows the company name and a zero-activity dashboard when nothing is happening',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanyHomeTab(
            companyName: 'ABC Logistics',
            companyJobRepository: FakeCompanyJobRepository(),
            truckRepository: FakeTruckRepository(),
            driverRepository: FakeDriverRepository(),
            featuredRepository: FakeCompanyFeaturedRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ABC Logistics'), findsOneWidget);
      expect(find.text('Accepting loads'), findsOneWidget);
      expect(find.text('No active job right now.'), findsOneWidget);
      expect(find.text('No open loads right now.'), findsOneWidget);
      expect(find.byType(PlusBadge), findsNothing);
      expect(find.text('Go further with Cargo Motives Plus'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the Plus badge and hides the promo banner for a featured company',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanyHomeTab(
            companyName: 'ABC Logistics',
            companyJobRepository: FakeCompanyJobRepository(),
            truckRepository: FakeTruckRepository(),
            driverRepository: FakeDriverRepository(),
            featuredRepository: FakeCompanyFeaturedRepository(
              onStatus: () async => const CompanyFeaturedStatus(
                isFeatured: true,
                featuredUntil: null,
                price: 5000,
                durationDays: 30,
                preferredRoutes: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlusBadge), findsOneWidget);
      expect(find.text('Go further with Cargo Motives Plus'), findsNothing);
    },
  );

  testWidgets('derives real stats and shows the active job', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CompanyHomeTab(
          companyName: 'ABC Logistics',
          companyJobRepository: FakeCompanyJobRepository(
            onActive: () async => [_job(id: 7, status: 'in_transit')],
            onMyBids: () async => [
              _job(id: 8, status: 'open'),
              _job(id: 9, status: 'completed'),
            ],
            onOpen: ({usePreferredRoutes = false}) async => [_job(id: 10)],
          ),
          truckRepository: FakeTruckRepository(
            onList: () async => [_truck(1), _truck(2)],
          ),
          driverRepository: FakeDriverRepository(
            onList: () async => [
              _driver(1, isActive: true),
              _driver(2, isActive: false),
            ],
          ),
          featuredRepository: FakeCompanyFeaturedRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsWidgets); // trips on the road + open bids
    expect(find.text('2'), findsWidgets); // fleet size
    expect(
      find.text('Tanga → Dodoma'),
      findsWidgets,
    ); // active job + matching load
    expect(find.text('Joseph Mwanga · T 123 ABC'), findsOneWidget);
  });
}

Truck _truck(int id) {
  return Truck(
    id: id,
    registrationNumber: 'T $id ABC',
    makeModel: 'Fuso',
    vehicleType: 'flatbed',
    capacityTons: 20,
    photoUrls: const [],
    verificationStatus: 'approved',
    rejectedReason: null,
    gpsStatus: 'not_connected',
    currentStatus: 'idle',
  );
}

Driver _driver(int id, {required bool isActive}) {
  return Driver(
    id: id,
    fullName: 'Driver $id',
    phoneNumber: '+2557000000$id',
    licenseNumber: null,
    photoUrl: null,
    isActive: isActive,
  );
}
