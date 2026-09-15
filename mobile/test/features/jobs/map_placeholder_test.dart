import 'package:cargo_motives/features/jobs/map_placeholder.dart';
import 'package:flutter/material.dart';
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
}
