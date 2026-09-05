import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/app.dart';
import 'package:plantcare_app/app/config/compile_time_environment_config.dart';
import 'package:plantcare_app/app/router/app_router.dart';
import 'package:plantcare_app/app/theme/theme_bloc.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/navigation.dart';
import 'package:plantcare_features/plant_identification.dart';
import 'package:plantcare_features/plants.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_plant_repository.dart';

class _Images implements PlantImagePicker, PlantImageProcessor {
  @override
  bool get supportsCamera => false;
  @override
  Future<PickedPlantImage?> pick(PlantImageSource source) async => null;
  @override
  Future<SelectedPlantImage> process(PickedPlantImage image) =>
      throw UnimplementedError();
}

class _Service implements PlantIdentificationService {
  @override
  Future<PlantIdentificationResult> identify({
    required SelectedPlantImage image,
  }) => throw UnimplementedError();
}

void main() {
  for (final path in [AppRoutes.newPlant, AppRoutes.manualPlant]) {
    testWidgets('protects and restores $path without transient extras', (
      tester,
    ) async {
      final auth = FakeAuthenticationRepository();
      final plants = FakePlantRepository();
      final session = AuthSessionBloc(auth);
      final theme = ThemeBloc();
      final images = _Images();
      final router = createAppRouter(
        authSessionBloc: session,
        authenticationBlocFactory: AuthenticationBlocFactory(auth),
        plantBlocFactory: PlantBlocFactory(plants),
        plantIdentificationBlocFactory: PlantIdentificationBlocFactory(
          images,
          images,
          _Service(),
          plants,
        ),
        initialLocation: path,
      );
      addTearDown(() async {
        router.dispose();
        await session.close();
        await theme.close();
        await auth.close();
        await plants.close();
      });
      await tester.pumpWidget(
        PlantCareApp(
          router: router,
          authSessionBloc: session,
          themeBloc: theme,
          environmentConfig: const CompileTimeEnvironmentConfig(),
        ),
      );
      await tester.pump();
      auth.emitAuthState(null);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.signIn);
      expect(router.state.uri.queryParameters['redirect'], path);
      auth.emitAuthState(const AppUser(uid: 'user', email: 'user@example.com'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, path);
      expect(
        find.text(
          path == AppRoutes.newPlant ? 'Identify from photo' : 'Common name',
        ),
        findsOneWidget,
      );
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('narrow-navigation')), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wide-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('rejects external or query-carried onboarding data', () {
    expect(
      validatedProtectedDestination(AppRoutes.newPlant),
      AppRoutes.newPlant,
    );
    expect(
      validatedProtectedDestination(AppRoutes.manualPlant),
      AppRoutes.manualPlant,
    );
    expect(
      validatedProtectedDestination('/plants/new?candidate=Tomato'),
      isNull,
    );
    expect(
      validatedProtectedDestination('https://evil.com/plants/new'),
      isNull,
    );
  });
}
