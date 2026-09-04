import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/app/bootstrap/app_bootstrap.dart';
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart';
import 'package:plantcare_ai/app/bootstrap/firebase_app_initializer.dart';
import 'package:plantcare_ai/app/bootstrap/startup_failure_app.dart';

void main() {
  test('runs the application after initialization succeeds', () async {
    final initializer = _FakeAppInitializer([null]);
    final applications = <Widget>[];

    await bootstrapApplication(
      initializer: initializer,
      applicationBuilder: () => const MaterialApp(home: Text('ready')),
      runApplication: applications.add,
    );

    expect(initializer.attempts, 1);
    expect(applications, hasLength(1));
    expect(applications.single, isA<MaterialApp>());
  });

  test(
    'runs the startup failure application after initialization fails',
    () async {
      final initializer = _FakeAppInitializer([StateError('unavailable')]);
      final applications = <Widget>[];
      final errors = <Object>[];

      await bootstrapApplication(
        initializer: initializer,
        applicationBuilder: () => const MaterialApp(home: Text('ready')),
        runApplication: applications.add,
        reportError: (error, _) => errors.add(error),
      );

      expect(initializer.attempts, 1);
      expect(applications.single, isA<StartupFailureApp>());
      expect(errors.single, isA<StateError>());
    },
  );

  testWidgets('retries initialization and runs the application on success', (
    tester,
  ) async {
    final initializer = _FakeAppInitializer([
      StateError('first attempt failed'),
      null,
    ]);
    final applications = <Widget>[];

    await bootstrapApplication(
      initializer: initializer,
      applicationBuilder: () => const MaterialApp(home: Text('ready')),
      runApplication: applications.add,
      reportError: (_, _) {},
    );

    await tester.pumpWidget(applications.single);
    expect(
      find.text(
        'PlantCare AI couldn\u2019t start. Check your connection and try again.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(initializer.attempts, 2);
    expect(applications, hasLength(2));
    expect(applications.last, isA<MaterialApp>());
  });

  testWidgets('returns to the failure view when a retry fails', (tester) async {
    final initializer = _FakeAppInitializer([
      StateError('first attempt failed'),
      StateError('retry failed'),
    ]);
    final applications = <Widget>[];

    await bootstrapApplication(
      initializer: initializer,
      applicationBuilder: () => const MaterialApp(home: Text('ready')),
      runApplication: applications.add,
      reportError: (_, _) {},
    );

    await tester.pumpWidget(applications.single);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(initializer.attempts, 2);
    expect(applications, hasLength(1));
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('App Check failure reaches the failure UI and retries safely', (
    tester,
  ) async {
    var firebaseAttempts = 0;
    var appCheckAttempts = 0;
    final applications = <Widget>[];
    final initializer = FirebaseAppInitializer(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'test-project-id',
      ),
      initializeFirebase: (_) async => firebaseAttempts++,
      activateAppCheck: () async {
        appCheckAttempts++;
        if (appCheckAttempts == 1) throw StateError('App Check unavailable');
      },
    );

    await bootstrapApplication(
      initializer: initializer,
      applicationBuilder: () => const MaterialApp(home: Text('ready')),
      runApplication: applications.add,
      reportError: (_, _) {},
    );

    await tester.pumpWidget(applications.single);
    expect(find.byType(StartupFailureApp), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(firebaseAttempts, 1);
    expect(appCheckAttempts, 2);
    expect(applications.last, isA<MaterialApp>());
  });
}

final class _FakeAppInitializer implements AppInitializer {
  _FakeAppInitializer(this._results);

  final List<Object?> _results;
  var attempts = 0;

  @override
  Future<void> initialize() async {
    final result = _results[attempts++];
    if (result case final Object error) {
      throw error;
    }
  }
}
