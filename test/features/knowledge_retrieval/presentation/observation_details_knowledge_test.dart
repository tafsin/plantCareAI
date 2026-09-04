import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/observation_details_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/pages/observation_details_page.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plants.dart';

import '../../../helpers/fake_knowledge_repository.dart';
import '../../../helpers/fake_plant_observation_dependencies.dart';
import '../../../helpers/fake_plant_repository.dart';

void main() {
  testWidgets('profile and AI conflict opens a local selection dialog', (
    tester,
  ) async {
    final plantRepository = FakePlantRepository();
    final observationRepository = FakePlantObservationRepository();
    final knowledgeRepository = FakeKnowledgeRepository();
    final plantBloc = PlantDetailsBloc(plantRepository)
      ..add(const PlantDetailsWatchRequested('plant-1'));
    final observationBloc = ObservationDetailsBloc(observationRepository)
      ..add(const ObservationDetailsWatchRequested('plant-1', 'observation-1'));
    final knowledgeBloc = KnowledgeRetrievalBloc(
      knowledgeRepository,
      const PlantNameResolver(),
      const KnowledgeRanker(),
    );
    addTearDown(() async {
      await plantBloc.close();
      await observationBloc.close();
      await knowledgeBloc.close();
      await plantRepository.close();
      await observationRepository.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: plantBloc),
            BlocProvider.value(value: observationBloc),
            BlocProvider.value(value: knowledgeBloc),
          ],
          child: const ObservationDetailsPage(
            plantId: 'plant-1',
            observationId: 'observation-1',
          ),
        ),
      ),
    );
    plantRepository.emitPlant('plant-1', _pumpkin);
    observationRepository.detailsController.add(
      sampleObservation.copyWith(id: 'observation-1', modelName: 'fake-model'),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Find relevant knowledge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find relevant knowledge'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Choose the plant for this retrieval'), findsOneWidget);
    expect(find.text('Use Tomato'), findsWidgets);
    expect(find.text('Use Pumpkin'), findsWidgets);

    final dialogChoice = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Use Tomato'),
    );
    await tester.tap(dialogChoice);
    await tester.pumpAndSettle();
    expect(knowledgeRepository.requestedPlantKey, 'tomato');
    expect(find.byKey(const ValueKey('knowledge-loaded')), findsOneWidget);
  });
}

const _pumpkin = Plant(
  id: 'plant-1',
  commonName: 'Pumpkin',
  scientificName: 'Cucurbita pepo',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.mature,
);
