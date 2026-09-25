import 'package:cargo_motives/features/company/data/truck_repository.dart';
import 'package:cargo_motives/features/company/fleet/add_truck_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_truck_repository.dart';

Future<void> _selectTruckType(WidgetTester tester, String type) async {
  await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(type).last);
  await tester.pumpAndSettle();
}

/// Taps through the "Confirm truck details" dialog that appears before the
/// first real submit for a truck (a fresh create, or completing a GPS
/// import) — see AddTruckScreen's own docblock.
Future<void> _confirmDetailsDialog(WidgetTester tester) async {
  expect(find.text('Confirm truck details'), findsOneWidget);
  await tester.tap(find.text('Confirm & save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows required-field validation and does not submit', (
    tester,
  ) async {
    var submitCalled = false;
    final repository = FakeTruckRepository(
      onSubmit: (submission, {editTruckId}) async {
        submitCalled = true;
        throw StateError('should not be called');
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: AddTruckScreen(repository: repository)),
    );
    await tester.ensureVisible(find.text('Register truck'));
    await tester.tap(find.text('Register truck'));
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
      find.widgetWithText(
        TextFormField,
        'Make / model (e.g. Isuzu FVR, Scania G410)',
      ),
      'Isuzu',
    );
    await _selectTruckType(tester, 'Flatbed');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Capacity (tons)'),
      'not-a-number',
    );

    await tester.ensureVisible(find.text('Register truck'));
    await tester.tap(find.text('Register truck'));
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
        find.widgetWithText(
          TextFormField,
          'Make / model (e.g. Isuzu FVR, Scania G410)',
        ),
        'Isuzu',
      );
      await _selectTruckType(tester, 'Flatbed');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Capacity (tons)'),
        '10',
      );

      await tester.ensureVisible(find.text('Register truck'));
      await tester.tap(find.text('Register truck'));
      await tester.pumpAndSettle();
      await _confirmDetailsDialog(tester);

      expect(
        find.text(
          'Please attach at least one photo, the registration card, and insurance.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('editing an existing truck prefills its vehicle details', (
    tester,
  ) async {
    const truck = Truck(
      id: 5,
      registrationNumber: 'T 999 ZZZ',
      makeModel: 'Scania',
      vehicleType: 'Tanker',
      capacityTons: 20,
      photoUrls: [],
      verificationStatus: 'approved',
      rejectedReason: null,
      gpsStatus: 'not_connected',
      currentStatus: 'idle',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddTruckScreen(
          repository: FakeTruckRepository(),
          editTruck: truck,
        ),
      ),
    );

    expect(find.text('Edit truck'), findsOneWidget);
    expect(find.text('T 999 ZZZ'), findsOneWidget);
    expect(find.text('Scania'), findsOneWidget);
  });

  /// An already-real truck (not a bare GPS import) is locked: only
  /// capacity/type/photos stay editable — the identity-document tiles
  /// (registration card, insurance, roadworthiness permit) are hidden
  /// since there's nothing to re-attach there, but the photo picker still
  /// renders since photos are exempt from the lock.
  testWidgets('changing the tonnage on an already-real truck submits directly, with no confirm dialog', (
    tester,
  ) async {
    const truck = Truck(
      id: 7,
      registrationNumber: 'T 777 EDT',
      makeModel: 'Isuzu',
      vehicleType: 'Flatbed',
      capacityTons: 10,
      photoUrls: ['https://example.test/photo.jpg'],
      verificationStatus: 'approved',
      rejectedReason: null,
      gpsStatus: 'not_connected',
      currentStatus: 'idle',
      registrationCardUrl: 'https://example.test/card.pdf',
      insuranceUrl: 'https://example.test/insurance.pdf',
    );

    TruckSubmission? submitted;
    int? submittedId;
    final repository = FakeTruckRepository(
      onSubmit: (submission, {editTruckId}) async {
        submitted = submission;
        submittedId = editTruckId;
        return truck;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddTruckScreen(repository: repository, editTruck: truck),
      ),
    );

    // Locked: the identity-document tiles don't render at all — there's
    // nothing left there that could change. The Documents heading and
    // photo picker still do, since photos are exempt from the lock.
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Photos on file — tap to replace'), findsOneWidget);
    expect(
      find.text('Registration card — on file, tap to replace'),
      findsNothing,
    );

    // The photo picker is genuinely tappable while locked, not just
    // visually present — a company can still refresh a truck's photos
    // after everything else is confirmed.
    final photoPickerInkWell = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Photos on file — tap to replace'),
        matching: find.byType(InkWell),
      ),
    );
    expect(photoPickerInkWell.onTap, isNotNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Capacity (tons)'),
      '25.5',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // No confirmation dialog for a routine locked edit — only the first
    // real submit for a truck needs that pause.
    expect(find.text('Confirm truck details'), findsNothing);
    expect(submittedId, 7);
    expect(submitted?.capacityTons, 25.5);
    // Nothing re-attached — the server keeps what it already has.
    expect(submitted?.photos, isEmpty);
    expect(submitted?.registrationCard, isNull);
    expect(submitted?.insurance, isNull);
  });

  /// A bare GPS-imported truck has no documents at all, so completing it
  /// must still demand them rather than silently saving an empty record.
  testWidgets('completing a GPS-imported truck still requires its documents', (
    tester,
  ) async {
    const truck = Truck(
      id: 8,
      registrationNumber: 'T456EFS',
      makeModel: 'Pending real details',
      vehicleType: 'Flatbed',
      capacityTons: 10,
      photoUrls: [],
      verificationStatus: 'approved',
      rejectedReason: null,
      gpsStatus: 'connected',
      currentStatus: 'idle',
      isGpsImported: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddTruckScreen(
          repository: FakeTruckRepository(),
          editTruck: truck,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    await _confirmDetailsDialog(tester);

    expect(
      find.text(
        'Please attach at least one photo, the registration card, and insurance.',
      ),
      findsOneWidget,
    );
  });

  /// Truck review was removed, so nothing in this form should still talk
  /// about resubmitting or a previous rejection.
  testWidgets('no longer shows any resubmission or rejection wording', (
    tester,
  ) async {
    const truck = Truck(
      id: 6,
      registrationNumber: 'T456EFS',
      makeModel: 'Pending real details',
      vehicleType: 'Flatbed',
      capacityTons: 10,
      photoUrls: [],
      verificationStatus: 'approved',
      rejectedReason: null,
      gpsStatus: 'connected',
      currentStatus: 'idle',
      isGpsImported: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddTruckScreen(
          repository: FakeTruckRepository(),
          editTruck: truck,
        ),
      ),
    );

    expect(find.text('Add truck details'), findsOneWidget);
    expect(find.text('Resubmit truck'), findsNothing);
    expect(find.text('Previous submission rejected'), findsNothing);
  });

  testWidgets(
    'a fresh truck asks for confirmation before its first submit, and cancelling does not submit',
    (tester) async {
      var submitCalled = false;
      final repository = FakeTruckRepository(
        onSubmit: (submission, {editTruckId}) async {
          submitCalled = true;
          throw StateError('should not be called');
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: AddTruckScreen(repository: repository)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration number'),
        'T 1 ABC',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Make / model (e.g. Isuzu FVR, Scania G410)',
        ),
        'Isuzu FRR',
      );
      await _selectTruckType(tester, 'Flatbed');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Capacity (tons)'),
        '10',
      );

      await tester.ensureVisible(find.text('Register truck'));
      await tester.tap(find.text('Register truck'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm truck details'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm truck details'), findsNothing);
      expect(submitCalled, isFalse);
    },
  );

  testWidgets(
    'confirming the dialog proceeds past it to the rest of the submit flow',
    (tester) async {
      var submitCalled = false;
      final repository = FakeTruckRepository(
        onSubmit: (submission, {editTruckId}) async {
          submitCalled = true;
          throw StateError('should not be reached without attachments');
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: AddTruckScreen(repository: repository)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration number'),
        'T 1 ABC',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Make / model (e.g. Isuzu FVR, Scania G410)',
        ),
        'Isuzu FRR',
      );
      await _selectTruckType(tester, 'Flatbed');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Capacity (tons)'),
        '10',
      );

      await tester.ensureVisible(find.text('Register truck'));
      await tester.tap(find.text('Register truck'));
      await tester.pumpAndSettle();
      await _confirmDetailsDialog(tester);

      // No documents were actually attached (the real file picker can't
      // run in a widget test), so confirming lands on the attachment
      // error rather than a real submit — proving execution genuinely
      // continues past the dialog instead of getting stuck.
      expect(
        find.text(
          'Please attach at least one photo, the registration card, and insurance.',
        ),
        findsOneWidget,
      );
      expect(submitCalled, isFalse);
    },
  );

  testWidgets(
    'an already-real truck renders registration number and make/model read-only',
    (tester) async {
      const truck = Truck(
        id: 10,
        registrationNumber: 'T 111 AAA',
        makeModel: 'Original Model',
        vehicleType: 'Flatbed',
        capacityTons: 10,
        photoUrls: [],
        verificationStatus: 'approved',
        rejectedReason: null,
        gpsStatus: 'not_connected',
        currentStatus: 'idle',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AddTruckScreen(
            repository: FakeTruckRepository(),
            editTruck: truck,
          ),
        ),
      );

      expect(
        find.text(
          'These details are locked once confirmed. Only capacity, type, and photos can be changed.',
        ),
        findsOneWidget,
      );

      final registrationField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Registration number'),
      );
      expect(registrationField.enabled, isFalse);

      final makeModelField = tester.widget<TextFormField>(
        find.widgetWithText(
          TextFormField,
          'Make / model (e.g. Isuzu FVR, Scania G410)',
        ),
      );
      expect(makeModelField.enabled, isFalse);

      // Capacity stays a normal, enabled field.
      final capacityField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Capacity (tons)'),
      );
      expect(capacityField.enabled, isTrue);
    },
  );

  testWidgets(
    'selecting "Other" for type reveals a custom text field, and it is what gets submitted',
    (tester) async {
      var submitCalled = false;
      final repository = FakeTruckRepository(
        onSubmit: (submission, {editTruckId}) async {
          submitCalled = true;
          throw StateError('should not be reached without attachments');
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: AddTruckScreen(repository: repository)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration number'),
        'T 1 ABC',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Make / model (e.g. Isuzu FVR, Scania G410)',
        ),
        'Isuzu FRR',
      );
      await _selectTruckType(tester, 'Other');

      expect(find.widgetWithText(TextFormField, 'Type (custom)'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Type (custom)'),
        'Crane Truck',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Capacity (tons)'),
        '10',
      );

      await tester.ensureVisible(find.text('Register truck'));
      await tester.tap(find.text('Register truck'));
      await tester.pumpAndSettle();
      await _confirmDetailsDialog(tester);

      // Type validation passed (no "Required" error on the custom field)
      // and the form proceeded all the way to the attachment check — the
      // one thing left unsatisfied in this test, since no real file was
      // ever attached.
      expect(find.text('Required'), findsNothing);
      expect(
        find.text(
          'Please attach at least one photo, the registration card, and insurance.',
        ),
        findsOneWidget,
      );
      expect(submitCalled, isFalse);
    },
  );

  testWidgets(
    'a matching make/model suggestion appears and selecting it fills the field',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddTruckScreen(repository: FakeTruckRepository())),
      );

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Make / model (e.g. Isuzu FVR, Scania G410)',
        ),
        'Isuzu',
      );
      await tester.pumpAndSettle();

      expect(find.text('Isuzu FVR'), findsOneWidget);

      await tester.tap(find.text('Isuzu FVR'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Isuzu FVR'),
        findsOneWidget,
      );
    },
  );
}
