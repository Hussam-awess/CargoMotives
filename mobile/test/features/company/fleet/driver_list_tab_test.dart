import 'package:cargo_motives/features/company/data/driver_repository.dart';
import 'package:cargo_motives/features/company/fleet/driver_list_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_driver_repository.dart';

const _driver = Driver(
  id: 1,
  fullName: 'Juma Hassan',
  phoneNumber: '+255712345678',
  licenseNumber: 'DL-123',
  photoUrl: null,
  isActive: true,
);

void main() {
  testWidgets('shows an empty state when there are no drivers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverListTab(
          repository: FakeDriverRepository(onList: () async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No drivers yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('lists drivers with name and phone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverListTab(
          repository: FakeDriverRepository(onList: () async => [_driver]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juma Hassan'), findsOneWidget);
    expect(find.textContaining('+255712345678'), findsOneWidget);
  });

  testWidgets('tapping a driver opens the edit form prefilled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverListTab(
          repository: FakeDriverRepository(onList: () async => [_driver]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Juma Hassan'));
    await tester.pumpAndSettle();

    expect(find.text('Edit driver'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
  });
}
