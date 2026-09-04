import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_form_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plants_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/pages/plant_details_page.dart';
import 'package:plantcare_ai/features/plants/presentation/pages/plant_form_page.dart';

import '../../../../helpers/fake_plant_repository.dart';
import '../../plant_test_data.dart';

void main() {
  testWidgets(
    'plant form validates common name and hides pot size for ground',
    (tester) async {
      final repository = FakePlantRepository();
      final bloc = PlantFormBloc(repository);
      addTearDown(() async {
        await bloc.close();
        await repository.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(value: bloc, child: const PlantFormPage()),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('plant-pot-size')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plant-growing-medium')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ground').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plant-pot-size')), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('plant-form-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('plant-form-submit')));
      await tester.pump();
      expect(find.text('Enter a common name.'), findsOneWidget);
      expect(repository.addCalls, 0);
    },
  );

  testWidgets('successful add navigates to the generated detail route', (
    tester,
  ) async {
    final repository = FakePlantRepository();
    final bloc = PlantFormBloc(repository);
    final router = GoRouter(
      initialLocation: '/plants/new',
      routes: [
        GoRoute(
          path: '/plants/new',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(value: bloc, child: const PlantFormPage()),
          ),
        ),
        GoRoute(
          path: '/plants/:plantId',
          builder: (_, state) =>
              Text('Detail ${state.pathParameters['plantId']}'),
        ),
        GoRoute(path: '/plants', builder: (_, _) => const Text('Plants')),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await bloc.close();
      await repository.close();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.enterText(
      find.byKey(const ValueKey('plant-common-name')),
      'Monstera',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('plant-form-submit')));
    await tester.tap(find.byKey(const ValueKey('plant-form-submit')));
    await tester.pumpAndSettle();

    expect(repository.addCalls, 1);
    expect(router.state.uri.path, '/plants/new-plant');
    expect(find.text('Detail new-plant'), findsOneWidget);
  });

  testWidgets('detail shows not found and confirms deletion with plant name', (
    tester,
  ) async {
    final repository = FakePlantRepository();
    final detailsBloc = PlantDetailsBloc(repository);
    final plantsBloc = PlantsBloc(repository);
    final router = GoRouter(
      initialLocation: '/plants/plant-1',
      routes: [
        GoRoute(path: '/plants', builder: (_, _) => const Text('Plants list')),
        GoRoute(
          path: '/plants/:plantId',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: detailsBloc),
              BlocProvider.value(value: plantsBloc),
            ],
            child: const PlantDetailsPage(plantId: 'plant-1'),
          ),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await detailsBloc.close();
      await plantsBloc.close();
      await repository.close();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    detailsBloc.add(const PlantDetailsChanged(null));
    await tester.pump();
    expect(find.byKey(const ValueKey('plant-not-found')), findsOneWidget);

    detailsBloc.add(PlantDetailsChanged(samplePlant));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete-plant')));
    await tester.pumpAndSettle();
    expect(
      find.text('Delete Monstera? This cannot be undone.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('confirm-delete-plant')));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
    expect(router.state.uri.path, '/plants');
    expect(find.text('Plants list'), findsOneWidget);
  });
}
