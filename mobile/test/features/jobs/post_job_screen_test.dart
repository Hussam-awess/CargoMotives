import 'dart:convert';

import 'package:cargo_motives/core/map/app_map.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/customer/addresses/saved_addresses_screen.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/post_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_job_repository.dart';

/// PostJobScreen is pushed onto the app's real Navigator stack via a plain
/// `Navigator.push(MaterialPageRoute(...))` (see CustomerHomeShell), and on
/// success push-replaces itself with ShipmentPostedScreen (which then pops
/// back with the imperative Navigator API) — so this wrapper uses a plain
/// Navigator, not GoRouter, matching real production wiring exactly.
Widget _appUnder({
  required JobRepository repository,
  Job? prefillReturnFrom,
  AuthRepository? authRepository,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostJobScreen(
                  repository: repository,
                  prefillReturnFrom: prefillReturnFrom,
                  authRepository: authRepository,
                ),
              ),
            ),
            child: const Text('Open post job'),
          ),
        ),
      ),
    ),
  );
}

/// Step 1 (Route) — fills pickup/drop-off and taps CONTINUE.
Future<void> _fillRouteStep(
  WidgetTester tester, {
  String pickupLat = '-6.8161',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Pickup address'),
    'Kariakoo, Dar es Salaam',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Latitude').first,
    pickupLat,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Longitude').first,
    '39.2803',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Drop-off address'),
    'Mbezi Beach, Dar es Salaam',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Latitude').last,
    '-6.7',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Longitude').last,
    '39.2',
  );
  await tester.ensureVisible(find.text('CONTINUE'));
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();
}

/// Step 2 (Cargo) — fills container type/size and taps CONTINUE.
Future<void> _fillCargoStep(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Container type (e.g. Dry Van, Reefer)'),
    'Dry Van',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Container size (e.g. 20ft, 40ft)'),
    '40ft',
  );
  await tester.ensureVisible(find.text('CONTINUE'));
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();
}

/// Fills all three steps up to (but not including) the final submit tap.
Future<void> _fillRequiredFields(WidgetTester tester) async {
  await _fillRouteStep(tester);
  await _fillCargoStep(tester);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Your budget, TZS'),
    '850000',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows required-field validation and does not submit', (
    tester,
  ) async {
    var postCalled = false;
    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(
          onPost: (s) async {
            postCalled = true;
            throw StateError('should not be called');
          },
        ),
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(postCalled, isFalse);
  });

  testWidgets('rejects a non-numeric coordinate', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pickup address'),
      'Kariakoo, Dar es Salaam',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude').first,
      'not-a-number',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude').first,
      '39.2803',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Drop-off address'),
      'Mbezi Beach, Dar es Salaam',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude').last,
      '-6.7',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude').last,
      '39.2',
    );

    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(find.text('Enter a number'), findsOneWidget);
  });

  testWidgets('requires a budget price before submitting', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRouteStep(tester);
    await _fillCargoStep(tester);
    // Budget price left blank, unlike _fillRequiredFields.

    await tester.ensureVisible(find.text('POST SHIPMENT'));
    await tester.tap(find.text('POST SHIPMENT'));
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('requires a pickup date/time before submitting', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await tester.ensureVisible(find.text('POST SHIPMENT'));
    await tester.tap(find.text('POST SHIPMENT'));
    await tester.pump();

    expect(
      find.text('Please choose a preferred pickup date and time.'),
      findsOneWidget,
    );
  });

  /// Navigates a month forward and picks the 15th, rather than accepting
  /// the date picker's own initialDate (tomorrow) — a pickup window only a
  /// day out leaves no room for a valid bidding deadline (Bidding Deadline
  /// epic: must be both >=1 day out AND strictly before the pickup date),
  /// so tests need a pickup date comfortably further out.
  Future<void> pickWindowStart(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Tap to choose'));
    await tester.tap(find.text('Tap to choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // confirms the chosen date
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // confirms the time picker's initialTime
    await tester.pumpAndSettle();
  }

  /// Taps the "5 days" bidding-deadline preset chip — call after
  /// [pickWindowStart] so the pickup window is already far enough out for
  /// this to land validly before it.
  Future<void> pickBiddingDeadline(WidgetTester tester) async {
    await tester.ensureVisible(find.text('5 days'));
    await tester.tap(find.text('5 days'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the server error message on failure', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(
          onPost: (s) async =>
              throw ApiException('Post-quota reached for today.'),
        ),
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await pickWindowStart(tester);
    await pickBiddingDeadline(tester);

    await tester.ensureVisible(find.text('POST SHIPMENT'));
    await tester.tap(find.text('POST SHIPMENT'));
    await tester.pumpAndSettle();

    expect(find.text('Post-quota reached for today.'), findsOneWidget);
  });

  testWidgets('requires a bidding deadline before submitting', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await pickWindowStart(tester);
    // Bidding deadline left unset, unlike pickBiddingDeadline.

    await tester.ensureVisible(find.text('POST SHIPMENT'));
    await tester.tap(find.text('POST SHIPMENT'));
    await tester.pump();

    expect(find.text('Please choose when bidding closes.'), findsOneWidget);
  });

  testWidgets(
    'a bidding-deadline preset chip fills the field and shows in the summary',
    (tester) async {
      await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
      await tester.tap(find.text('Open post job'));
      await tester.pumpAndSettle();

      await _fillRequiredFields(tester);
      await pickWindowStart(tester);
      await pickBiddingDeadline(tester);

      expect(find.textContaining('Bidding closes'), findsOneWidget);
    },
  );

  testWidgets('a cargo type chip fills the container type field', (
    tester,
  ) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRouteStep(tester);
    await tester.tap(find.text('Machinery'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Machinery'), findsOneWidget);
  });

  testWidgets('rejects a trucks-needed value below 1', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRouteStep(tester);
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Container type (e.g. Dry Van, Reefer)',
      ),
      'Dry Van',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Container size (e.g. 20ft, 40ft)'),
      '40ft',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Trucks needed'),
      '0',
    );
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(find.text('Enter at least 1'), findsOneWidget);
  });

  testWidgets('a bulk job\'s budget field is labeled per truck', (
    tester,
  ) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRouteStep(tester);
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Container type (e.g. Dry Van, Reefer)',
      ),
      'Dry Van',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Container size (e.g. 20ft, 40ft)'),
      '40ft',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Trucks needed'),
      '20',
    );
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('Your budget, TZS (per truck)'), findsOneWidget);
    expect(
      find.textContaining('per truck, not the total for all trucks'),
      findsOneWidget,
    );
  });

  testWidgets('an ordinary job\'s budget field has no per-truck label', (
    tester,
  ) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRouteStep(tester);
    await _fillCargoStep(tester);

    expect(find.text('Your budget, TZS'), findsOneWidget);
    expect(find.text('Your budget, TZS (per truck)'), findsNothing);
  });

  testWidgets('posts a bulk cargo job with the entered trucks-needed count', (
    tester,
  ) async {
    JobSubmission? captured;
    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(
          onPost: (s) async {
            captured = s;
            return Job(
              id: 1,
              status: 'open',
              pickupAddress: s.pickupAddress,
              pickupLat: s.pickupLat,
              pickupLng: s.pickupLng,
              dropoffAddress: s.dropoffAddress,
              dropoffLat: s.dropoffLat,
              dropoffLng: s.dropoffLng,
              containerType: s.containerType,
              containerSize: s.containerSize,
              trucksNeeded: s.trucksNeeded,
              approxWeightTons: s.approxWeightTons,
              cargoDescription: s.cargoDescription,
              preferredPickupWindowStart: s.preferredPickupWindowStart,
              customerNotes: s.customerNotes,
              agreedPrice: null,
              currency: 'TZS',
              assignedCompanyName: null,
              assignedTruckRegistration: null,
              assignedDriverName: null,
              proofOfDelivery: null,
              bidsCount: 0,
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRouteStep(tester);
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Container type (e.g. Dry Van, Reefer)',
      ),
      'Dry Van',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Container size (e.g. 20ft, 40ft)'),
      '40ft',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Trucks needed'),
      '20',
    );
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('Trucks needed'), findsOneWidget);
    expect(find.text('20'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your budget, TZS (per truck)'),
      '850000',
    );
    await pickWindowStart(tester);
    await pickBiddingDeadline(tester);

    await tester.ensureVisible(find.text('POST SHIPMENT'));
    await tester.tap(find.text('POST SHIPMENT'));
    await tester.pumpAndSettle();

    expect(captured?.trucksNeeded, 20);
  });

  testWidgets('BACK returns to the previous step without losing entered data', (
    tester,
  ) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRouteStep(tester);
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Kariakoo, Dar es Salaam'),
      findsOneWidget,
    );
  });

  testWidgets('posts the job and returns to the previous screen', (
    tester,
  ) async {
    JobSubmission? captured;
    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(
          onPost: (s) async {
            captured = s;
            return Job(
              id: 1,
              status: 'open',
              pickupAddress: s.pickupAddress,
              pickupLat: s.pickupLat,
              pickupLng: s.pickupLng,
              dropoffAddress: s.dropoffAddress,
              dropoffLat: s.dropoffLat,
              dropoffLng: s.dropoffLng,
              containerType: s.containerType,
              containerSize: s.containerSize,
              approxWeightTons: s.approxWeightTons,
              cargoDescription: s.cargoDescription,
              preferredPickupWindowStart: s.preferredPickupWindowStart,
              customerNotes: s.customerNotes,
              agreedPrice: null,
              currency: 'TZS',
              assignedCompanyName: null,
              assignedTruckRegistration: null,
              assignedDriverName: null,
              proofOfDelivery: null,
              bidsCount: 0,
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await pickWindowStart(tester);
    await pickBiddingDeadline(tester);

    await tester.ensureVisible(find.text('POST SHIPMENT'));
    await tester.tap(find.text('POST SHIPMENT'));
    await tester.pumpAndSettle();

    expect(captured?.pickupAddress, 'Kariakoo, Dar es Salaam');
    expect(captured?.trucksNeeded, 1);
    expect(find.text('Your shipment is live'), findsOneWidget);
    expect(find.textContaining('CM-0001'), findsWidgets);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Open post job'), findsOneWidget);
  });

  testWidgets('defaults the currency picker to the customers own preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(),
        authRepository: FakeAuthRepository(
          onMe: () async => const UserProfile(
            fullName: 'Amina',
            companyName: null,
            isFeatured: false,
            preferredCurrency: 'USD',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRouteStep(tester);
    await _fillCargoStep(tester);

    expect(
      find.widgetWithText(TextFormField, 'Your budget, USD'),
      findsOneWidget,
    );
  });

  testWidgets('submits the customer-chosen currency with the job', (
    tester,
  ) async {
    JobSubmission? captured;
    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(
          onPost: (s) async {
            captured = s;
            return Job(
              id: 1,
              status: 'open',
              pickupAddress: s.pickupAddress,
              pickupLat: s.pickupLat,
              pickupLng: s.pickupLng,
              dropoffAddress: s.dropoffAddress,
              dropoffLat: s.dropoffLat,
              dropoffLng: s.dropoffLng,
              containerType: s.containerType,
              containerSize: s.containerSize,
              approxWeightTons: s.approxWeightTons,
              cargoDescription: s.cargoDescription,
              preferredPickupWindowStart: s.preferredPickupWindowStart,
              customerNotes: s.customerNotes,
              agreedPrice: null,
              currency: s.currency,
              assignedCompanyName: null,
              assignedTruckRegistration: null,
              assignedDriverName: null,
              proofOfDelivery: null,
              bidsCount: 0,
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await pickWindowStart(tester);
    await pickBiddingDeadline(tester);

    await tester.ensureVisible(find.text('USD'));
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('POST SHIPMENT'));
    await tester.tap(find.text('POST SHIPMENT'));
    await tester.pumpAndSettle();

    expect(captured?.currency, 'USD');
  });

  testWidgets(
    'prefillReturnFrom reverses the route and carries over the container details',
    (tester) async {
      final completedJob = Job(
        id: 7,
        status: 'completed',
        pickupAddress: 'Kariakoo, Dar es Salaam',
        pickupLat: -6.8161,
        pickupLng: 39.2803,
        dropoffAddress: 'Mbezi Beach, Dar es Salaam',
        dropoffLat: -6.7,
        dropoffLng: 39.2,
        containerType: 'Dry Van',
        containerSize: '40ft',
        approxWeightTons: 12,
        cargoDescription: 'Cement bags',
        preferredPickupWindowStart: DateTime(2026, 1, 1, 9),
        customerNotes: null,
        agreedPrice: null,
        currency: 'TZS',
        assignedCompanyName: null,
        assignedTruckRegistration: null,
        assignedDriverName: null,
        proofOfDelivery: null,
        bidsCount: 0,
      );

      await tester.pumpWidget(
        _appUnder(
          repository: FakeJobRepository(),
          prefillReturnFrom: completedJob,
        ),
      );
      await tester.tap(find.text('Open post job'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Mbezi Beach, Dar es Salaam'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Kariakoo, Dar es Salaam'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('CONTINUE'));
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Dry Van'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '40ft'), findsOneWidget);
    },
  );

  testWidgets('prefillReturnFrom carries over the original jobs currency', (
    tester,
  ) async {
    final completedUsdJob = Job(
      id: 8,
      status: 'completed',
      pickupAddress: 'Kariakoo, Dar es Salaam',
      pickupLat: -6.8161,
      pickupLng: 39.2803,
      dropoffAddress: 'Mbezi Beach, Dar es Salaam',
      dropoffLat: -6.7,
      dropoffLng: 39.2,
      containerType: 'Dry Van',
      containerSize: '40ft',
      approxWeightTons: 12,
      cargoDescription: null,
      preferredPickupWindowStart: DateTime(2026, 1, 1, 9),
      customerNotes: null,
      agreedPrice: null,
      currency: 'USD',
      assignedCompanyName: null,
      assignedTruckRegistration: null,
      assignedDriverName: null,
      proofOfDelivery: null,
      bidsCount: 0,
    );

    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(),
        prefillReturnFrom: completedUsdJob,
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Your budget, USD'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping the pickup map fills the pickup latitude/longitude fields',
    (tester) async {
      await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
      await tester.tap(find.text('Open post job'));
      await tester.pumpAndSettle();

      final pickupMap = find.byType(AppMap).first;
      expect(pickupMap, findsOneWidget);
      await tester.tapAt(tester.getCenter(pickupMap));
      // flutter_map's gesture arena waits out the double-tap-to-zoom window
      // before firing a plain onTap — pumpAndSettle alone doesn't advance
      // wall-clock time far enough to clear it.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final pickupLat = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Latitude').first,
      );
      final pickupLng = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Longitude').first,
      );
      expect(double.tryParse(pickupLat.controller!.text), isNotNull);
      expect(double.tryParse(pickupLng.controller!.text), isNotNull);
    },
  );

  testWidgets(
    'the map\'s clear button also blanks the pickup/drop-off address fields',
    (tester) async {
      await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
      await tester.tap(find.text('Open post job'));
      await tester.pumpAndSettle();

      final map = find.byType(AppMap).first;
      // Drop a pickup pin, then a drop-off pin (mode auto-advances).
      await tester.tapAt(tester.getCenter(map));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(tester.getCenter(map));
      await tester.pumpAndSettle();

      final pickupAddress = find.widgetWithText(
        TextFormField,
        'Pickup address',
      );
      await tester.enterText(pickupAddress, 'Some pickup address');
      await tester.pumpAndSettle();

      // Entering text into a field further down the form scrolls it into
      // view, which can carry the Clear button (positioned above the map)
      // off-screen — bring it back into view before tapping it.
      await tester.ensureVisible(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(pickupAddress).controller!.text,
        isEmpty,
      );
      final pickupLat = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Latitude').first,
      );
      expect(pickupLat.controller!.text, isEmpty);
    },
  );

  testWidgets(
    'shows saved addresses as quick-fill chips on the route map',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'customer.saved_addresses': <String>[
          jsonEncode({
            'label': 'Warehouse',
            'address': 'Kariakoo, Dar es Salaam',
            'lat': -6.8161,
            'lng': 39.2803,
          }),
        ],
      });

      await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
      await tester.tap(find.text('Open post job'));
      await tester.pumpAndSettle();

      expect(find.text('Warehouse'), findsOneWidget);
      await tester.tap(find.text('Warehouse'));
      await tester.pumpAndSettle();

      final pickupLat = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Latitude').first,
      );
      final pickupLng = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Longitude').first,
      );
      expect(pickupLat.controller!.text, '-6.816100');
      expect(pickupLng.controller!.text, '39.280300');
      expect(
        find.widgetWithText(TextFormField, 'Kariakoo, Dar es Salaam'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping "Save pickup as address" adds a new saved address',
    (tester) async {
      await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
      await tester.tap(find.text('Open post job'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pickup address'),
        'Kariakoo, Dar es Salaam',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Latitude').first,
        '-6.8161',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Longitude').first,
        '39.2803',
      );

      await tester.ensureVisible(find.text('Save pickup as address'));
      await tester.tap(find.text('Save pickup as address'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextField, 'Kariakoo, Dar es Salaam'),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Label (e.g. Warehouse, Home)'),
        'Warehouse',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Address saved.'), findsOneWidget);

      final saved = await loadSavedAddresses();
      expect(saved, hasLength(1));
      expect(saved.first.label, 'Warehouse');
      expect(saved.first.lat, -6.8161);
      expect(saved.first.lng, 39.2803);
    },
  );

  testWidgets(
    '"Save as address" refuses without a point on the map yet',
    (tester) async {
      await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
      await tester.tap(find.text('Open post job'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save pickup as address'));
      await tester.tap(find.text('Save pickup as address'));
      await tester.pumpAndSettle();

      expect(
        find.text('Set a pickup point on the map first.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
