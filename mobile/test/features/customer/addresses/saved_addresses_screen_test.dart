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

  test('a SavedAddress round-trips its coordinates through JSON', () {
    const original = SavedAddress(
      label: 'Warehouse',
      address: 'Kariakoo, Dar es Salaam',
      lat: -6.8161,
      lng: 39.2803,
    );

    final restored = SavedAddress.fromJson(original.toJson());

    expect(restored.label, 'Warehouse');
    expect(restored.address, 'Kariakoo, Dar es Salaam');
    expect(restored.lat, -6.8161);
    expect(restored.lng, 39.2803);
  });

  test('a SavedAddress saved without coordinates round-trips as null', () {
    const original = SavedAddress(
      label: 'Home',
      address: 'Mbezi Beach, Dar es Salaam',
    );

    final restored = SavedAddress.fromJson(original.toJson());

    expect(restored.lat, isNull);
    expect(restored.lng, isNull);
  });

  testWidgets(
    'addSavedAddress adds an entry directly, outside this screen',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final addFuture = addSavedAddress(
        context: capturedContext,
        isFeatured: false,
        initialAddress: 'Kariakoo, Dar es Salaam',
        lat: -6.8161,
        lng: 39.2803,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Kariakoo, Dar es Salaam'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Label (e.g. Warehouse, Home)'),
        'Warehouse',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(await addFuture, isTrue);
      final saved = await loadSavedAddresses();
      expect(saved, hasLength(1));
      expect(saved.first.label, 'Warehouse');
      expect(saved.first.lat, -6.8161);
    },
  );
}
