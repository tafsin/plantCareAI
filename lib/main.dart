import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/app.dart';
import 'package:plantcare_ai/app/bootstrap/app_bootstrap.dart';
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart';
import 'package:plantcare_ai/app/dependency_injection/injection.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/app/theme/theme_bloc.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_shared/environment.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = FlutterError.presentError;
    await configureDependencies();

    await bootstrapApplication(
      initializer: getIt<AppInitializer>(),
      applicationBuilder: () => PlantCareApp(
        router: getIt<GoRouter>(),
        themeBloc: getIt<ThemeBloc>(),
        authSessionBloc: getIt<AuthSessionBloc>(),
        environmentConfig: getIt<EnvironmentConfig>(),
      ),
    );
    getIt<NotificationScheduler>().notificationTapPayloads.listen((location) {
      final destination = validatedProtectedDestination(location);
      if (destination != null) getIt<GoRouter>().go(destination);
    });
  }, _reportUncaughtError);
}

void _reportUncaughtError(Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('Uncaught PlantCare AI error: ${error.runtimeType}');
    debugPrintStack(stackTrace: stackTrace);
  }
}
