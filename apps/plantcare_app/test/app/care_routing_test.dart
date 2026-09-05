import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_app/app/app.dart';
import 'package:plantcare_app/app/config/compile_time_environment_config.dart';
import 'package:plantcare_app/app/router/app_router.dart';
import 'package:plantcare_app/app/theme/theme_bloc.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/care_history.dart';
import 'package:plantcare_features/navigation.dart';
import 'package:plantcare_features/plants.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_care_log_dependencies.dart';
import '../helpers/fake_plant_repository.dart';

void main() {
  testWidgets('care form is protected and preserves its valid type query', (
    tester,
  ) async {
    final location = AppRoutes.newCareLog('plant-1', CareLogType.watering);
    final harness = await _pump(tester, location);
    harness.auth.emitAuthState(null);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, AppRoutes.signIn);
    expect(harness.router.state.uri.queryParameters['redirect'], location);
  });

  testWidgets('invalid or missing care type shows safe validation', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      '/plants/plant-1/care/new?type=unknown',
    );
    harness.auth.emitAuthState(
      const AppUser(uid: 'alice', email: 'a@test.com'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose either watering or fertilizing.'), findsOneWidget);
  });

  testWidgets('invalid plant and log IDs show not found', (tester) async {
    final missingPlant = await _pump(tester, AppRoutes.careHistory('missing'));
    missingPlant.auth.emitAuthState(
      const AppUser(uid: 'alice', email: 'a@test.com'),
    );
    await tester.pump();
    missingPlant.plants.emitPlant('missing', null);
    await tester.pumpAndSettle();
    expect(find.text('Plant not found.'), findsOneWidget);

    final missingLog = await _pump(
      tester,
      AppRoutes.careLogDetails('plant-1', 'missing'),
    );
    missingLog.auth.emitAuthState(
      const AppUser(uid: 'alice', email: 'a@test.com'),
    );
    await tester.pump();
    missingLog.plants.emitPlant('plant-1', _plant);
    await tester.pumpAndSettle();
    expect(find.text('Care log not found.'), findsOneWidget);
  });
}

Future<
  ({
    FakeAuthenticationRepository auth,
    FakePlantRepository plants,
    GoRouter router,
  })
>
_pump(WidgetTester tester, String location) async {
  final auth = FakeAuthenticationRepository();
  final plants = FakePlantRepository();
  final care = FakeCareLogRepository();
  final session = AuthSessionBloc(auth);
  final theme = ThemeBloc();
  final router = createAppRouter(
    authSessionBloc: session,
    authenticationBlocFactory: AuthenticationBlocFactory(auth),
    plantBlocFactory: PlantBlocFactory(plants),
    careLogBlocFactory: CareLogBlocFactory(care),
    initialLocation: location,
  );
  addTearDown(() async {
    router.dispose();
    await session.close();
    await theme.close();
    await auth.close();
    await plants.close();
    await care.close();
  });
  await tester.pumpWidget(
    PlantCareApp(
      router: router,
      themeBloc: theme,
      authSessionBloc: session,
      environmentConfig: const CompileTimeEnvironmentConfig(),
    ),
  );
  await tester.pump();
  return (auth: auth, plants: plants, router: router);
}

const _plant = Plant(
  id: 'plant-1',
  commonName: 'Pothos',
  environment: PlantEnvironment.indoor,
  growingMedium: GrowingMedium.pot,
  sunlight: Sunlight.partial,
  growthStage: GrowthStage.mature,
);
