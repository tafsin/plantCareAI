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
import 'package:plantcare_features/plant_observation.dart';
import 'package:plantcare_features/plants.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_plant_observation_dependencies.dart';
import '../helpers/fake_plant_repository.dart';

void main() {
  testWidgets('shows loading and does not redirect during initial checking', (
    tester,
  ) async {
    final harness = await _pumpHarness(
      tester,
      initialLocation: AppRoutes.plants,
    );

    expect(find.byKey(const ValueKey('auth-loading')), findsOneWidget);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      AppRoutes.plants,
    );

    harness.repository.emitAuthState(null);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.signIn);
    expect(
      harness.router.state.uri.queryParameters['redirect'],
      AppRoutes.plants,
    );
  });

  testWidgets('observation route requires authentication', (tester) async {
    final location = AppRoutes.observePlant('plant-1');
    final harness = await _pumpHarness(tester, initialLocation: location);

    harness.repository.emitAuthState(null);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.signIn);
    expect(harness.router.state.uri.queryParameters['redirect'], location);
  });

  testWidgets('invalid plant id shows not found on observation route', (
    tester,
  ) async {
    final harness = await _pumpHarness(
      tester,
      initialLocation: AppRoutes.observePlant('missing'),
    );
    harness.repository.emitAuthState(
      const AppUser(uid: 'user-1', email: 'user@test.com'),
    );
    await tester.pump();
    harness.plantRepository.emitPlant('missing', null);
    await tester.pumpAndSettle();

    expect(find.text('Plant not found'), findsOneWidget);
  });

  testWidgets('redirects authenticated users away from auth routes', (
    tester,
  ) async {
    final harness = await _pumpHarness(
      tester,
      initialLocation: '${AppRoutes.signIn}?redirect=%2Fplants',
    );

    harness.repository.emitAuthState(
      const AppUser(uid: 'user-1', email: 'user@test.com'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.router.state.uri.path, AppRoutes.plants);
    expect(find.byKey(const ValueKey('my-plants-page')), findsOneWidget);
  });

  testWidgets('rejects external and auth-route preserved destinations', (
    tester,
  ) async {
    expect(validatedProtectedDestination('https://example.com'), isNull);
    expect(validatedProtectedDestination(AppRoutes.register), isNull);
    expect(validatedProtectedDestination(AppRoutes.plants), AppRoutes.plants);
    expect(
      validatedProtectedDestination('/plants/plant-1/edit'),
      '/plants/plant-1/edit',
    );
    expect(
      validatedProtectedDestination('/plants/plant-1/soil-checks/new'),
      '/plants/plant-1/soil-checks/new',
    );
    expect(
      validatedProtectedDestination('/plants/plant-1/soil-checks'),
      '/plants/plant-1/soil-checks',
    );
    expect(
      validatedProtectedDestination('/plants/plant-1/soil-checks/check-1'),
      '/plants/plant-1/soil-checks/check-1',
    );
    expect(
      validatedProtectedDestination(
        '/plants/plant-1/fertilizer-assessments/new',
      ),
      '/plants/plant-1/fertilizer-assessments/new',
    );
    expect(
      validatedProtectedDestination(
        '/plants/plant-1/fertilizer-assessments/assessment-1',
      ),
      '/plants/plant-1/fertilizer-assessments/assessment-1',
    );

    final harness = await _pumpHarness(
      tester,
      initialLocation: '${AppRoutes.signIn}?redirect=https%3A%2F%2Fexample.com',
    );
    harness.repository.emitAuthState(
      const AppUser(uid: 'user-1', email: 'user@test.com'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.router.state.uri.path, AppRoutes.home);
  });

  testWidgets('logout failure stays put and shows the requested message', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    harness.repository
      ..signOutError = const AuthenticationFailure(
        AuthenticationFailureType.network,
        'technical failure',
      )
      ..emitAuthState(const AppUser(uid: 'user-1', email: 'user@test.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('logout-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.router.state.uri.path, AppRoutes.home);
    expect(find.text('Couldn\'t sign out. Please try again.'), findsOneWidget);
    expect(harness.repository.signOutCalls, 1);
  });

  testWidgets('successful logout is redirected by the auth stream', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    harness.repository.emitAuthState(
      const AppUser(uid: 'user-1', email: 'user@test.com'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('logout-button')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, AppRoutes.signIn);
    expect(harness.repository.signOutCalls, 1);
  });
}

Future<
  ({
    FakeAuthenticationRepository repository,
    AuthSessionBloc sessionBloc,
    ThemeBloc themeBloc,
    GoRouter router,
    FakePlantRepository plantRepository,
  })
>
_pumpHarness(
  WidgetTester tester, {
  String initialLocation = AppRoutes.home,
}) async {
  final repository = FakeAuthenticationRepository();
  final plantRepository = FakePlantRepository();
  final observationRepository = FakePlantObservationRepository();
  final observationFactory = PlantObservationBlocFactory(
    FakePlantImagePicker(),
    FakePlantImageProcessor(),
    FakePlantObservationService(),
    observationRepository,
  );
  final sessionBloc = AuthSessionBloc(repository);
  final themeBloc = ThemeBloc();
  final router = createAppRouter(
    authSessionBloc: sessionBloc,
    authenticationBlocFactory: AuthenticationBlocFactory(repository),
    plantBlocFactory: PlantBlocFactory(plantRepository),
    plantObservationBlocFactory: observationFactory,
    initialLocation: initialLocation,
  );
  addTearDown(() async {
    router.dispose();
    await sessionBloc.close();
    await themeBloc.close();
    await repository.close();
    await plantRepository.close();
    await observationRepository.close();
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
  return (
    repository: repository,
    sessionBloc: sessionBloc,
    themeBloc: themeBloc,
    router: router,
    plantRepository: plantRepository,
  );
}
