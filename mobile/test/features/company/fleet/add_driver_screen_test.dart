import 'package:cargo_motives/features/company/data/driver_repository.dart';
import 'package:cargo_motives/features/company/fleet/add_driver_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_driver_repository.dart';

void main() {
  testWidgets('shows required-field validation and does not save', (
    tester,
  ) async {
    var saveCalled = false;
    final repository = FakeDriverRepository(
      onSave:
          ({
            driverId,
            required fullName,
            required phoneNumber,
            licenseNumber,
            licensePhoto,
          }) async {
            saveCalled = true;
            throw StateError('should not be called');
          },
    );

    await tester.pumpWidget(
      MaterialApp(home: AddDriverScreen(repository: repository)),
    );
    await tester.tap(find.text('Save driver'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(2));
    expect(saveCalled, isFalse);
  });

  testWidgets('saves a valid driver', (tester) async {
    var saveCalled = false;
    final repository = FakeDriverRepository(
      onSave:
          ({
            driverId,
            required fullName,
            required phoneNumber,
            licenseNumber,
            licensePhoto,
          }) async {
            saveCalled = true;
            expect(fullName, 'Juma Hassan');
            expect(phoneNumber, '0712345678');
            return Driver(
              id: 1,
              fullName: fullName,
              phoneNumber: phoneNumber,
              licenseNumber: licenseNumber,
              photoUrl: null,
              isActive: true,
            );
          },
    );

    await tester.pumpWidget(
      MaterialApp(home: AddDriverScreen(repository: repository)),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Juma Hassan',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '0712345678',
    );
    await tester.tap(find.text('Save driver'));
    await tester.pumpAndSettle();

    expect(saveCalled, isTrue);
  });
}
