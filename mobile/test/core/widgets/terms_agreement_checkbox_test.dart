import 'package:cargo_motives/core/widgets/terms_agreement_checkbox.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _appUnder(Widget child) {
  return MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders both legal links as separately tappable text', (tester) async {
    await tester.pumpWidget(_appUnder(TermsAgreementCheckbox(value: false, onChanged: (_) {})));
    await tester.pumpAndSettle();

    // All spans (prefix/link/middle/link/suffix) combine into one
    // Text.rich, so find.textContaining checks the assembled plain text
    // rather than matching any single span in isolation.
    expect(find.textContaining('I agree to the Terms and Conditions and Privacy Policy.'), findsOneWidget);

    // Confirms the two phrases are real tap targets (a TapGestureRecognizer
    // on their own span), not just plain inert text alongside a link-blue
    // style — the visual color alone wouldn't make them clickable.
    final richText = tester.widget<RichText>(find.byType(RichText));
    // Text.rich wraps the given span in its own outer TextSpan (to apply
    // DefaultTextStyle), so the span this widget actually built is one
    // level deeper — richText.text.children.first, not richText.text
    // itself.
    final outerSpan = richText.text as TextSpan;
    final span = outerSpan.children!.first as TextSpan;
    final tappableTexts = span.children!
        .whereType<TextSpan>()
        .where((s) => s.recognizer is TapGestureRecognizer)
        .map((s) => s.text)
        .toList();
    expect(tappableTexts, ['Terms and Conditions', 'Privacy Policy']);
  });

  testWidgets('tapping the checkbox itself toggles it, not the surrounding text', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _appUnder(
        StatefulBuilder(
          builder: (context, setState) => TermsAgreementCheckbox(value: value, onChanged: (v) => setState(() => value = v)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(value, isTrue);
  });
}
