import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/post_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_job_repository.dart';

/// PostJobScreen is pushed onto the app's real Navigator stack (see
/// CustomerHomeShell) and calls `context.pop(true)` on success, so this
/// wrapper gives it an actual GoRouter back-stack to pop — the same
/// pattern ProfileSetupScreenTest uses for `context.go`.
Widget _appUnder({required JobRepository repository}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(onPressed: () => context.push('/post-job'), child: const Text('Open post job')),
          ),
        ),
      ),
      GoRoute(path: '/post-job', builder: (context, state) => PostJobScreen(repository: repository)),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

Future<void> _fillRequiredFields(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Pickup address'), 'Kariakoo, Dar es Salaam');
  await tester.enterText(find.widgetWithText(TextFormField, 'Latitude').first, '-6.8161');
  await tester.enterText(find.widgetWithText(TextFormField, 'Longitude').first, '39.2803');
  await tester.enterText(find.widgetWithText(TextFormField, 'Drop-off address'), 'Mbezi Beach, Dar es Salaam');
  await tester.enterText(find.widgetWithText(TextFormField, 'Latitude').last, '-6.7');
  await tester.enterText(find.widgetWithText(TextFormField, 'Longitude').last, '39.2');
  await tester.enterText(find.widgetWithText(TextFormField, 'Container type (e.g. Dry Van, Reefer)'), 'Dry Van');
  await tester.enterText(find.widgetWithText(TextFormField, 'Container size (e.g. 20ft, 40ft)'), '40ft');
}

void main() {
  testWidgets('shows required-field validation and does not submit', (tester) async {
    var postCalled = false;
    await tester.pumpWidget(
      _appUnder(repository: FakeJobRepository(onPost: (s) async {
        postCalled = true;
        throw StateError('should not be called');
      })),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Post job'));
    await tester.tap(find.text('Post job'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(postCalled, isFalse);
  });

  testWidgets('rejects a non-numeric coordinate', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Latitude').first, 'not-a-number');

    await tester.ensureVisible(find.text('Post job'));
    await tester.tap(find.text('Post job'));
    await tester.pump();

    expect(find.text('Enter a number'), findsOneWidget);
  });

  testWidgets('requires a pickup date/time before submitting', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeJobRepository()));
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await tester.ensureVisible(find.text('Post job'));
    await tester.tap(find.text('Post job'));
    await tester.pump();

    expect(find.text('Please choose a preferred pickup date and time.'), findsOneWidget);
  });

  Future<void> pickWindowStart(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Tap to choose'));
    await tester.tap(find.text('Tap to choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // confirms the date picker's initialDate
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // confirms the time picker's initialTime
    await tester.pumpAndSettle();
  }

  testWidgets('shows the server error message on failure', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(
          onPost: (s) async => throw ApiException('Post-quota reached for today.'),
        ),
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await pickWindowStart(tester);

    await tester.ensureVisible(find.text('Post job'));
    await tester.tap(find.text('Post job'));
    await tester.pumpAndSettle();

    expect(find.text('Post-quota reached for today.'), findsOneWidget);
  });

  testWidgets('posts the job and returns to the previous screen', (tester) async {
    JobSubmission? captured;
    await tester.pumpWidget(
      _appUnder(
        repository: FakeJobRepository(
          onPost: (s) async {
            captured = s;
            return Job(
              id: 1,
              status: 'open',
              pickupAddress: s.pickupAddress,
              pickupLat: s.pickupLat,
              pickupLng: s.pickupLng,
              dropoffAddress: s.dropoffAddress,
              dropoffLat: s.dropoffLat,
              dropoffLng: s.dropoffLng,
              containerType: s.containerType,
              containerSize: s.containerSize,
              approxWeightTons: s.approxWeightTons,
              cargoDescription: s.cargoDescription,
              preferredPickupWindowStart: s.preferredPickupWindowStart,
              customerNotes: s.customerNotes,
              agreedPrice: null,
              currency: 'TZS',
              assignedCompanyName: null,
              assignedTruckRegistration: null,
              assignedDriverName: null,
              proofOfDelivery: null,
              bidsCount: 0,
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open post job'));
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await pickWindowStart(tester);

    await tester.ensureVisible(find.text('Post job'));
    await tester.tap(find.text('Post job'));
    await tester.pumpAndSettle();

    expect(captured?.pickupAddress, 'Kariakoo, Dar es Salaam');
    expect(find.text('Open post job'), findsOneWidget);
  });
}
