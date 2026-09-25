import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/support/active_sessions_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

Widget _appUnder(Widget home) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);

ActiveSession _session(int id, String name, {bool current = false}) =>
    ActiveSession(id: id, deviceName: name, lastUsedAt: DateTime(2026, 9, 24, 10), createdAt: DateTime(2026, 9, 1), isCurrent: current);

void main() {
  testWidgets('lists every session and tags the current device', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        ActiveSessionsScreen(
          authRepository: FakeAuthRepository(
            onSessions: () async => [_session(1, 'Android device', current: true), _session(2, 'iPhone')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Android device'), findsOneWidget);
    expect(find.text('iPhone'), findsOneWidget);
    expect(find.text('This device'), findsOneWidget);
    // Only the other device offers a Sign out button.
    expect(find.widgetWithText(TextButton, 'Sign out'), findsOneWidget);
  });

  testWidgets('signing out another device revokes it and refreshes the list', (tester) async {
    var sessions = [_session(1, 'Android device', current: true), _session(2, 'iPhone')];
    int? revoked;

    await tester.pumpWidget(
      _appUnder(
        ActiveSessionsScreen(
          authRepository: FakeAuthRepository(
            onSessions: () async => sessions,
            onRevokeSession: (id) async {
              revoked = id;
              sessions = sessions.where((s) => s.id != id).toList();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(revoked, 2);
    expect(find.text('iPhone'), findsNothing);
    expect(find.text('No other devices are signed in to your account.'), findsOneWidget);
  });

  testWidgets('"Sign out all other devices" revokes everything but this one', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _appUnder(
        ActiveSessionsScreen(
          authRepository: FakeAuthRepository(
            onSessions: () async => called
                ? [_session(1, 'Android device', current: true)]
                : [_session(1, 'Android device', current: true), _session(2, 'iPhone'), _session(3, 'Web browser')],
            onRevokeOtherSessions: () async => called = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out all other devices'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(find.text('Signed out of all other devices.'), findsOneWidget);
  });

  testWidgets('shows a retry option when the list cannot load', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _appUnder(
        ActiveSessionsScreen(
          authRepository: FakeAuthRepository(
            onSessions: () async {
              attempts++;
              if (attempts == 1) throw Exception('offline');
              return [_session(1, 'Android device', current: true)];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your sessions.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Android device'), findsOneWidget);
  });
}
