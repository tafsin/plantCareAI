import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart';
import 'package:plantcare_ai/app/bootstrap/startup_failure_app.dart';

typedef ApplicationBuilder = Widget Function();
typedef ApplicationRunner = void Function(Widget application);
typedef StartupErrorReporter = void Function(
  Object error,
  StackTrace stackTrace,
);

Future<void> bootstrapApplication({
  required AppInitializer initializer,
  required ApplicationBuilder applicationBuilder,
  ApplicationRunner runApplication = runApp,
  StartupErrorReporter reportError = _reportStartupError,
}) async {
  Future<bool> initialize() async {
    try {
      await initializer.initialize();
      return true;
    } catch (error, stackTrace) {
      reportError(error, stackTrace);
      return false;
    }
  }

  if (await initialize()) {
    runApplication(applicationBuilder());
    return;
  }

  runApplication(
    StartupFailureApp(
      onRetry: () async {
        final initialized = await initialize();
        if (initialized) {
          runApplication(applicationBuilder());
        }
        return initialized;
      },
    ),
  );
}

void _reportStartupError(Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('PlantCare AI startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
