import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/app.dart';
import 'package:plantcare_app/app/config/compile_time_environment_config.dart';
import 'package:plantcare_app/app/router/app_router.dart';
import 'package:plantcare_app/app/theme/theme_bloc.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/navigation.dart';
import 'package:plantcare_features/plant_identification.dart';
import 'package:plantcare_features/plants.dart';
import 'package:plantcare_features/premium_subscriptions.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_local_plant_image_repository.dart';
import '../helpers/fake_plant_repository.dart';
import '../helpers/fake_premium_dependencies.dart';

class _Images implements PlantImagePicker, PlantImageProcessor {
  int pickCalls = 0;

  @override
  bool get supportsCamera => false;
  @override
  Future<PickedPlantImage?> pick(PlantImageSource source) async {
    pickCalls++;
    return null;
  }

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
        plantBlocFactory: PlantBlocFactory(
          plants,
          FakeLocalPlantImageRepository(),
        ),
        plantIdentificationBlocFactory: PlantIdentificationBlocFactory(
          images,
          images,
          _Service(),
          plants,
          FakeLocalPlantImageRepository(),
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
  for (final path in [AppRoutes.newPlant, AppRoutes.manualPlant]) {
    testWidgets(
      'Free limit guards direct $path and verified upgrade returns there',
      (tester) async {
        final auth = FakeAuthenticationRepository();
        final plants = FakePlantRepository();
        final premium = FakePremiumSubscriptionRepository();
        final premiumFactory = PremiumBlocFactory(
          premium,
          FakePremiumDestinationLauncher(),
        );
        final premiumAccessBloc = premiumFactory.createAccessBloc();
        final session = AuthSessionBloc(auth);
        final theme = ThemeBloc();
        final images = _Images();
        final localImages = FakeLocalPlantImageRepository();
        final router = createAppRouter(
          authSessionBloc: session,
          authenticationBlocFactory: AuthenticationBlocFactory(auth),
          plantBlocFactory: PlantBlocFactory(plants, localImages, premium),
          plantIdentificationBlocFactory: PlantIdentificationBlocFactory(
            images,
            images,
            _Service(),
            plants,
            localImages,
            premium,
          ),
          premiumBlocFactory: premiumFactory,
          initialLocation: path,
        );
        addTearDown(() async {
          router.dispose();
          await premiumAccessBloc.close();
          await premium.dispose();
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
            premiumAccessBloc: premiumAccessBloc,
            environmentConfig: const CompileTimeEnvironmentConfig(),
          ),
        );
        auth.emitAuthState(
          const AppUser(uid: 'user-1', email: 'user@example.com'),
        );
        await tester.pump();
        plants.emitPlants(_plants(3));
        await tester.pumpAndSettle();

        expect(
          find.text(PlantCapabilityPolicy.plantLimitMessage),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('plant-limit-reached')),
          findsOneWidget,
        );
        expect(images.pickCalls, 0);
        expect(find.text('Common name'), findsNothing);
        expect(find.text('Identify from photo'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('plant-limit-upgrade')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.premium);
        expect(router.state.uri.queryParameters['returnTo'], path);

        premium.emitEvent(const PaywallPurchaseCancelled());
        await tester.pump();
        expect(router.state.uri.path, AppRoutes.premium);

        premium.emitAccess(
          const PremiumAccessSnapshot(
            userId: 'user-1',
            status: PremiumAccessStatus.active,
          ),
        );
        premium.emitEvent(const PaywallPurchaseVerified());
        await tester.pumpAndSettle();

        expect(router.state.uri.path, path);
        expect(
          find.text(
            path == AppRoutes.newPlant ? 'Identify from photo' : 'Common name',
          ),
          findsOneWidget,
        );
      },
    );
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
      validatedProtectedDestination(
        AppRoutes.premiumLocation(returnTo: AppRoutes.newPlant),
      ),
      AppRoutes.premiumLocation(returnTo: AppRoutes.newPlant),
    );
    expect(
      validatedProtectedDestination('/premium?returnTo=https://evil.com'),
      isNull,
    );
    expect(
      validatedProtectedDestination('https://evil.com/plants/new'),
      isNull,
    );
  });
}

List<Plant> _plants(int count) => List.generate(
  count,
  (index) => Plant(
    id: 'plant-$index',
    commonName: 'Plant $index',
    environment: PlantEnvironment.indoor,
    growingMedium: GrowingMedium.pot,
    sunlight: Sunlight.partial,
    growthStage: GrowthStage.vegetative,
  ),
);
