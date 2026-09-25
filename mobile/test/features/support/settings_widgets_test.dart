import 'package:cargo_motives/features/support/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping anywhere on a toggle row flips it', (tester) async {
    bool? changedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToggleRow(title: 'Shipment updates', value: false, onChanged: (v) => changedTo = v),
        ),
      ),
    );

    await tester.tap(find.text('Shipment updates'));
    await tester.pump();

    expect(changedTo, isTrue);
  });

  testWidgets('a screen reader hears the toggle title and state together', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToggleRow(title: 'Shipment updates', value: true, onChanged: (_) {}),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(Switch));
    expect(node.label, contains('Shipment updates'));
    expect(node.getSemanticsData().flagsCollection.isToggled, isTrue);
    handle.dispose();
  });

  testWidgets('a tappable nav row is announced as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsNavRow(title: 'Active sessions', onTap: () {})),
      ),
    );

    expect(find.bySemanticsLabel('Active sessions'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Active sessions')).getSemanticsData().flagsCollection.isButton, isTrue);
    handle.dispose();
  });
}
