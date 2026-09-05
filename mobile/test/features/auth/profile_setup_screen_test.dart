import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/auth/profile_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';

Widget _appUnder({required FakeAuthRepository repository}) {
  final router = GoRouter(
    initialLocation: '/profile-setup',
    routes: [
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) =>
            ProfileSetupScreen(authRepository: repository),
      ),
      GoRoute(
        path: '/customer',
        builder: (context, state) => const Text('CUSTOMER_HOME'),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets(
    'shows a validation error and does not submit when name is empty',
    (tester) async {
      var submitted = false;
      final repository = FakeAuthRepository(
        onCompleteProfile: (name) async => submitted = true,
      );

      await tester.pumpWidget(_appUnder(repository: repository));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Enter your name.'), findsOneWidget);
      expect(submitted, isFalse);
    },
  );

  testWidgets('completes the profile and navigates to Customer Home', (
    tester,
  ) async {
    String? capturedName;
    final repository = FakeAuthRepository(
      onCompleteProfile: (name) async => capturedName = name,
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), 'Asha Mwinyi');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(capturedName, 'Asha Mwinyi');
    expect(find.text('CUSTOMER_HOME'), findsOneWidget);
  });

  testWidgets('shows the server error message on failure', (tester) async {
    final repository = FakeAuthRepository(
      onCompleteProfile: (name) async =>
          throw ApiException('Something went wrong. Please try again.'),
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), 'Asha Mwinyi');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Your details'), findsOneWidget);
  });
}
