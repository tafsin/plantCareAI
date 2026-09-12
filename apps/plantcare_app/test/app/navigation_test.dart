import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_app/app/app.dart';
import 'package:plantcare_app/app/config/compile_time_environment_config.dart';
import 'package:plantcare_app/app/router/app_router.dart';
import 'package:plantcare_app/app/theme/theme_bloc.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/navigation.dart';
import 'package:plantcare_features/plants.dart';
import 'package:plantcare_features/premium_subscriptions.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_local_plant_image_repository.dart';
import '../helpers/fake_plant_repository.dart';
import '../helpers/fake_premium_dependencies.dart';

void main() {
  testWidgets('navigates from Home to My Plants', (tester) async {
    final repository = FakeAuthenticationRepository();
    final plantRepository = FakePlantRepository();
    final sessionBloc = AuthSessionBloc(repository);
    final themeBloc = ThemeBloc();
    final router = createAppRouter(
      authSessionBloc: sessionBloc,
      authenticationBlocFactory: AuthenticationBlocFactory(repository),
      plantBlocFactory: PlantBlocFactory(
        plantRepository,
        FakeLocalPlantImageRepository(),
      ),
    );
    addTearDown(() async {
      router.dispose();
      await sessionBloc.close();
      await themeBloc.close();
      await repository.close();
      await plantRepository.close();
    });
    await tester.pumpWidget(_testApp(router, sessionBloc, themeBloc));
    await tester.pump();
    repository.emitAuthState(
      const AppUser(uid: 'user-1', email: 'user@test.com'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('home-page')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plants-destination')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.state.uri.path, AppRoutes.plants);
    expect(find.byKey(const ValueKey('my-plants-page')), findsOneWidget);
  });

  testWidgets('upgrade entry opens Premium without changing destinations', (
    tester,
  ) async {
    final repository = FakeAuthenticationRepository();
    final plantRepository = FakePlantRepository();
    final premiumRepository = FakePremiumSubscriptionRepository();
    final premiumFactory = PremiumBlocFactory(
      premiumRepository,
      FakePremiumDestinationLauncher(),
    );
    final premiumAccessBloc = premiumFactory.createAccessBloc();
    final sessionBloc = AuthSessionBloc(repository);
    final themeBloc = ThemeBloc();
    final router = createAppRouter(
      authSessionBloc: sessionBloc,
      authenticationBlocFactory: AuthenticationBlocFactory(repository),
      plantBlocFactory: PlantBlocFactory(
        plantRepository,
        FakeLocalPlantImageRepository(),
      ),
      premiumBlocFactory: premiumFactory,
    );
    addTearDown(() async {
      router.dispose();
      await sessionBloc.close();
      await themeBloc.close();
      await premiumAccessBloc.close();
      await premiumRepository.dispose();
      await repository.close();
      await plantRepository.close();
    });
    await tester.pumpWidget(
      PlantCareApp(
        router: router,
        themeBloc: themeBloc,
        authSessionBloc: sessionBloc,
        environmentConfig: const CompileTimeEnvironmentConfig(),
        premiumAccessBloc: premiumAccessBloc,
      ),
    );
    repository.emitAuthState(
      const AppUser(uid: 'user-1', email: 'user@test.com'),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Upgrade to Premium'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('upgrade-premium-button')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.premium);
    expect(find.text('Premium'), findsWidgets);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });
}

Widget _testApp(
  GoRouter router,
  AuthSessionBloc sessionBloc,
  ThemeBloc themeBloc,
) {
  return PlantCareApp(
    router: router,
    themeBloc: themeBloc,
    authSessionBloc: sessionBloc,
    environmentConfig: const CompileTimeEnvironmentConfig(),
  );
}
