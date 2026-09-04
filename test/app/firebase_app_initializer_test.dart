import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/app/bootstrap/firebase_app_initializer.dart';

void main() {
  const options = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project-id',
  );

  test('forwards Firebase options and initializes once', () async {
    final receivedOptions = <FirebaseOptions>[];
    final initializer = FirebaseAppInitializer(
      options: options,
      initializeFirebase: (value) async => receivedOptions.add(value),
    );

    await initializer.initialize();
    await initializer.initialize();

    expect(receivedOptions, [options]);
  });

  test(
    'runs Firebase, emulators, App Check, and services in order once',
    () async {
      final operations = <String>[];
      final initializer = FirebaseAppInitializer(
        options: options,
        initializeFirebase: (_) async => operations.add('firebase'),
        configureEmulators: () async => operations.add('emulators'),
        activateAppCheck: () async => operations.add('app_check'),
        startApplicationServices: () async => operations.add('services'),
      );

      await initializer.initialize();
      await initializer.initialize();

      expect(operations, ['firebase', 'emulators', 'app_check', 'services']);
    },
  );

  test(
    'retries App Check without repeating completed bootstrap steps',
    () async {
      var firebaseAttempts = 0;
      var emulatorAttempts = 0;
      var appCheckAttempts = 0;
      final initializer = FirebaseAppInitializer(
        options: options,
        initializeFirebase: (_) async => firebaseAttempts++,
        configureEmulators: () async => emulatorAttempts++,
        activateAppCheck: () async {
          appCheckAttempts++;
          if (appCheckAttempts == 1) {
            throw StateError('App Check unavailable');
          }
        },
      );

      await expectLater(initializer.initialize(), throwsStateError);
      await initializer.initialize();

      expect(firebaseAttempts, 1);
      expect(emulatorAttempts, 1);
      expect(appCheckAttempts, 2);
    },
  );

  test('shares an in-progress initialization attempt', () async {
    final completion = Completer<void>();
    var attempts = 0;
    final initializer = FirebaseAppInitializer(
      options: options,
      initializeFirebase: (_) {
        attempts++;
        return completion.future;
      },
    );

    final first = initializer.initialize();
    final second = initializer.initialize();
    completion.complete();
    await Future.wait([first, second]);

    expect(attempts, 1);
  });

  test('allows retry after a failed initialization attempt', () async {
    var attempts = 0;
    final initializer = FirebaseAppInitializer(
      options: options,
      initializeFirebase: (_) async {
        attempts++;
        if (attempts == 1) {
          throw StateError('initialization failed');
        }
      },
    );

    await expectLater(initializer.initialize(), throwsStateError);
    await initializer.initialize();

    expect(attempts, 2);
  });
}
