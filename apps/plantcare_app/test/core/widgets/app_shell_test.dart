import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/core/widgets/app_shell.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/navigation.dart';

import '../../helpers/fake_authentication_repository.dart';

void main() {
  late FakeAuthenticationRepository repository;
  late AuthSessionBloc sessionBloc;

  setUp(() {
    repository = FakeAuthenticationRepository();
    sessionBloc = AuthSessionBloc(repository);
  });

  tearDown(() async {
    await sessionBloc.close();
    await repository.close();
  });

  Future<void> show(
    WidgetTester tester, {
    required String location,
    double width = 390,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: sessionBloc,
          child: AppShell(location: location, child: const SizedBox()),
        ),
      ),
    );
  }

  testWidgets('uses the fixed app bar for add plant', (tester) async {
    await show(tester, location: AppRoutes.newPlant);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Add plant'),
      ),
      findsOneWidget,
    );
    expect(find.text('My Plants'), findsOneWidget);
  });

  testWidgets('uses the fixed app bar for plant health check', (tester) async {
    await show(tester, location: AppRoutes.healthCheck('plant-1'));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Plant Health Check'),
      ),
      findsOneWidget,
    );
    expect(find.text('My Plants'), findsOneWidget);
  });

  testWidgets('omits the redundant narrow My Plants app-bar title', (
    tester,
  ) async {
    await show(tester, location: AppRoutes.plants);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('My Plants'),
      ),
      findsNothing,
    );
    expect(find.text('My Plants'), findsOneWidget);
  });

  testWidgets('keeps the My Plants title beside wide navigation', (
    tester,
  ) async {
    await show(tester, location: AppRoutes.plants, width: 1200);

    expect(find.byKey(const ValueKey('shell-branding')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('My Plants'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps wide shell branding responsive at large text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await show(tester, location: AppRoutes.plants, width: 840);

    expect(find.byKey(const ValueKey('shell-branding')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
