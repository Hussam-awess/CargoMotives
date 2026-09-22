import 'package:cargo_motives/features/jobs/map_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Flutter's default test surface size.
  const screenSize = Size(800, 600);

  testWidgets('fills the available space when given a marker child', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapPlaceholder(child: Container(key: const Key('marker'))),
            ],
          ),
        ),
      ),
    );

    // CustomPaint sizes itself to its own child whenever one is given — the
    // real bug this pins: MapPlaceholder used to silently collapse to that
    // child's own small size instead of filling the Stack behind it.
    final size = tester.getSize(find.byType(MapPlaceholder));
    expect(size, screenSize);
  });

  testWidgets(
    'fills the available space with no child at all (e.g. an empty fleet)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Stack(children: [MapPlaceholder()])),
        ),
      );

      // CustomPaint's own `size` param defaults to Size.zero and is only
      // honored when child is null — without an explicit size on the
      // placeholder itself, this state collapsed to nothing too.
      final size = tester.getSize(find.byType(MapPlaceholder));
      expect(size, screenSize);
    },
  );

  testWidgets(
    'TruckFleetMarker renders a truck glyph tinted the given color, outlined in white, with no circular badge behind it',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TruckFleetMarker(color: Colors.green)),
        ),
      );

      // Two layered copies of the same glyph: a slightly larger all-white
      // one for the outline, and the actual status-colored one on top —
      // not a single icon inside a colored circle badge.
      final svgs = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .toList();
      expect(svgs, hasLength(2));
      expect(
        svgs.map((s) => s.colorFilter),
        containsAll([
          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          const ColorFilter.mode(Colors.green, BlendMode.srcIn),
        ]),
      );

      final circleDecorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle);
      expect(circleDecorations, isEmpty);
    },
  );

  testWidgets(
    'TruckFleetMarker shows the plate/driver label above the glyph when given one',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TruckFleetMarker(
              color: Colors.green,
              label: 'T123ABC Juma Hassan',
            ),
          ),
        ),
      );

      expect(find.text('T123ABC Juma Hassan'), findsOneWidget);
    },
  );

  testWidgets('TruckFleetMarker shows no label pill when none is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TruckFleetMarker(color: Colors.green)),
      ),
    );

    expect(find.byType(Text), findsNothing);
  });
}
