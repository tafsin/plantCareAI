import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/app.dart';
import 'package:plantcare_ai/app/config/compile_time_environment_config.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/app/theme/theme_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/auth_session_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/authentication_bloc_factory.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_bloc_factory.dart';
import 'package:plantcare_domain/authentication.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_plant_repository.dart';

void main() {
  testWidgets('switches navigation for narrow and wide layouts', (
    tester,
  ) async {
    final repository = FakeAuthenticationRepository();
    final plantRepository = FakePlantRepository();
    final sessionBloc = AuthSessionBloc(repository);
    final themeBloc = ThemeBloc();
    final router = createAppRouter(
      authSessionBloc: sessionBloc,
      authenticationBlocFactory: AuthenticationBlocFactory(repository),
      plantBlocFactory: PlantBlocFactory(plantRepository),
    );
    addTearDown(() async {
      router.dispose();
      await sessionBloc.close();
      await themeBloc.close();
      await repository.close();
      await plantRepository.close();
    });
    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_testApp(router, sessionBloc, themeBloc));
    await tester.pump();
    repository.emitAuthState(
      const AppUser(uid: 'user-1', email: 'user@test.com'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('narrow-navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('wide-navigation')), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('narrow-navigation')), findsNothing);
    expect(find.byKey(const ValueKey('wide-navigation')), findsOneWidget);
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
