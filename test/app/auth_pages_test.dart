import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/app.dart';
import 'package:plantcare_ai/app/config/compile_time_environment_config.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/app/theme/theme_bloc.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/navigation.dart';
import 'package:plantcare_features/plants.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_plant_repository.dart';

void main() {
  testWidgets('successful sign-in continues to the protected destination', (
    tester,
  ) async {
    final harness = await _signedOutHarness(
      tester,
      initialLocation: AppRoutes.plants,
    );

    await tester.enterText(
      find.byKey(const ValueKey('sign-in-email')),
      'user@test.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('sign-in-password')),
      'plant123',
    );
    await tester.tap(find.byKey(const ValueKey('sign-in-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.repository.signInCalls, 1);
    expect(harness.router.state.uri.path, AppRoutes.plants);
  });

  testWidgets('failed sign-in displays an inline safe message', (tester) async {
    final harness = await _signedOutHarness(tester);
    harness.repository.signInError = const AuthenticationFailure(
      AuthenticationFailureType.invalidCredentials,
      'We couldn\'t sign you in. Check your email and password and try again.',
    );

    await tester.enterText(
      find.byKey(const ValueKey('sign-in-email')),
      'user@test.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('sign-in-password')),
      'wrong123',
    );
    await tester.tap(find.byKey(const ValueKey('sign-in-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-error')), findsOneWidget);
    expect(
      find.text(
        'We couldn\'t sign you in. Check your email and password and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('registration signs in and continues to protected destination', (
    tester,
  ) async {
    final harness = await _signedOutHarness(
      tester,
      initialLocation: '${AppRoutes.register}?redirect=%2Fplants',
    );

    await tester.enterText(
      find.byKey(const ValueKey('register-email')),
      'new@test.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password')),
      'plant123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password')),
      'plant123',
    );
    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.repository.registerCalls, 1);
    expect(harness.router.state.uri.path, AppRoutes.plants);
  });

  testWidgets('password reset returns to sign-in with a neutral message', (
    tester,
  ) async {
    final harness = await _signedOutHarness(
      tester,
      initialLocation: AppRoutes.forgotPassword,
    );

    await tester.enterText(
      find.byKey(const ValueKey('reset-email')),
      'user@test.com',
    );
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();

    expect(harness.repository.passwordResetCalls, 1);
    expect(harness.router.state.uri.path, AppRoutes.signIn);
    expect(find.text(passwordResetSuccessMessage), findsOneWidget);
  });
}

Future<
  ({
    FakeAuthenticationRepository repository,
    AuthSessionBloc sessionBloc,
    ThemeBloc themeBloc,
    GoRouter router,
  })
>
_signedOutHarness(
  WidgetTester tester, {
  String initialLocation = AppRoutes.signIn,
}) async {
  final repository = FakeAuthenticationRepository();
  final plantRepository = FakePlantRepository();
  final sessionBloc = AuthSessionBloc(repository);
  final themeBloc = ThemeBloc();
  final router = createAppRouter(
    authSessionBloc: sessionBloc,
    authenticationBlocFactory: AuthenticationBlocFactory(repository),
    plantBlocFactory: PlantBlocFactory(plantRepository),
    initialLocation: initialLocation,
  );
  addTearDown(() async {
    router.dispose();
    await sessionBloc.close();
    await themeBloc.close();
    await repository.close();
    await plantRepository.close();
  });

  await tester.pumpWidget(
    PlantCareApp(
      router: router,
      themeBloc: themeBloc,
      authSessionBloc: sessionBloc,
      environmentConfig: const CompileTimeEnvironmentConfig(),
    ),
  );
  await tester.pump();
  repository.emitAuthState(null);
  await tester.pumpAndSettle();

  return (
    repository: repository,
    sessionBloc: sessionBloc,
    themeBloc: themeBloc,
    router: router,
  );
}
