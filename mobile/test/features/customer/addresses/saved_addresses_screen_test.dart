import 'package:cargo_motives/features/customer/addresses/saved_addresses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _addAddress(WidgetTester tester, String label, String address) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Label (e.g. Warehouse, Home)'), label);
  await tester.enterText(find.widgetWithText(TextField, 'Address'), address);
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a standard account is capped at 3 saved addresses with an upsell prompt', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedAddressesScreen()));
    await tester.pumpAndSettle();

    await _addAddress(tester, 'Warehouse', 'Kariakoo, Dar es Salaam');
    await _addAddress(tester, 'Home', 'Mbezi Beach, Dar es Salaam');
    await _addAddress(tester, 'Office', 'Masaki, Dar es Salaam');

    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.textContaining('3 of 3'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Standard accounts can save up to 3 addresses. Get Cargo Motives Plus to save more.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a Plus account is not capped and shows no counter', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedAddressesScreen(isFeatured: true)));
    await tester.pumpAndSettle();

    await _addAddress(tester, 'Warehouse', 'Kariakoo, Dar es Salaam');
    await _addAddress(tester, 'Home', 'Mbezi Beach, Dar es Salaam');
    await _addAddress(tester, 'Office', 'Masaki, Dar es Salaam');
    await _addAddress(tester, 'Yard', 'Ubungo, Dar es Salaam');

    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Yard'), findsOneWidget);
    expect(find.textContaining('of 3'), findsNothing);
  });
}
