import 'package:cargo_motives/features/company/data/truck_repository.dart';
import 'package:cargo_motives/features/company/fleet/add_truck_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_truck_repository.dart';

void main() {
  testWidgets('shows required-field validation and does not submit', (
    tester,
  ) async {
    var submitCalled = false;
    final repository = FakeTruckRepository(
      onSubmit: (submission, {resubmitTruckId}) async {
        submitCalled = true;
        throw StateError('should not be called');
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: AddTruckScreen(repository: repository)),
    );
    await tester.ensureVisible(find.text('Submit for review'));
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    expect(submitCalled, isFalse);
  });

  testWidgets('rejects a non-numeric capacity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AddTruckScreen(repository: FakeTruckRepository())),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Registration number'),
      'T 1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Make / model'),
      'Isuzu',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Type (e.g. Flatbed, Tanker)'),
      'Flatbed',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Capacity (tons)'),
      'not-a-number',
    );

    await tester.ensureVisible(find.text('Submit for review'));
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a number'), findsOneWidget);
  });

  testWidgets(
    'filling fields but missing attachments shows an attachment error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddTruckScreen(repository: FakeTruckRepository())),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration number'),
        'T 1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Make / model'),
        'Isuzu',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Type (e.g. Flatbed, Tanker)'),
        'Flatbed',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Capacity (tons)'),
        '10',
      );

      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Please attach at least one photo, the registration card, and insurance.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows the rejection reason banner when resubmitting a rejected truck',
    (tester) async {
      const truck = Truck(
        id: 5,
        registrationNumber: 'T 999 ZZZ',
        makeModel: 'Scania',
        vehicleType: 'Tanker',
        capacityTons: 20,
        photoUrls: [],
        verificationStatus: 'rejected',
        rejectedReason: 'Photos too blurry.',
        gpsStatus: 'not_connected',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AddTruckScreen(
            repository: FakeTruckRepository(),
            resubmitTruck: truck,
          ),
        ),
      );

      expect(find.text('Previous submission rejected'), findsOneWidget);
      expect(find.text('Photos too blurry.'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Registration number'),
        findsOneWidget,
      );
    },
  );
}
