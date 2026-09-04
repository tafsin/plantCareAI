import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/errors/knowledge_retrieval_failure.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/knowledge_ranker.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/widgets/knowledge_retrieval_panel.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

import '../../../helpers/fake_knowledge_repository.dart';
import '../../../helpers/fake_plant_observation_dependencies.dart';

void main() {
  testWidgets(
    'shows initial, loading, loaded, attribution and disclaimer states',
    (tester) async {
      final repository = FakeKnowledgeRepository();
      final completer = Completer<KnowledgeDocuments<KnowledgeChunk>>();
      repository.chunkCompleter = completer;
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      Uri? opened;
      await tester.pumpWidget(
        _app(
          bloc,
          _tomato,
          opener: (uri) async {
            opened = uri;
            return true;
          },
        ),
      );
      expect(
        find.byKey(const ValueKey('find-relevant-knowledge')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('find-relevant-knowledge')));
      await tester.pump();
      expect(find.byKey(const ValueKey('knowledge-loading')), findsOneWidget);
      completer.complete(repository.chunks);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('knowledge-loaded')), findsOneWidget);
      expect(find.text('Relevant plant-care knowledge'), findsOneWidget);
      expect(find.textContaining('not a confirmed diagnosis'), findsOneWidget);
      expect(find.textContaining('University Extension'), findsOneWidget);
      await tester.tap(find.textContaining('University Extension'));
      await tester.pump();
      expect(opened, Uri.parse(sampleKnowledgeSource.url));
    },
  );

  testWidgets('shows unsupported and conflict states', (tester) async {
    final repository = FakeKnowledgeRepository();
    final bloc = _bloc(repository);
    addTearDown(bloc.close);
    await tester.pumpWidget(_app(bloc, _monstera, observation: _withoutAi));
    await tester.tap(find.text('Find relevant knowledge'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('knowledge-unsupported')), findsOneWidget);

    final conflictBloc = _bloc(repository);
    addTearDown(conflictBloc.close);
    await tester.pumpWidget(_app(conflictBloc, _pumpkin));
    conflictBloc.add(
      const KnowledgeRetrievalRequested(
        plant: _pumpkin,
        observation: sampleObservation,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('knowledge-conflict')), findsOneWidget);
    expect(find.text('Use Tomato'), findsOneWidget);
    expect(find.text('Use Pumpkin'), findsOneWidget);
  });

  testWidgets('shows empty, failure and retry states', (tester) async {
    final repository = FakeKnowledgeRepository()
      ..chunks = const KnowledgeDocuments(items: []);
    final bloc = _bloc(repository);
    addTearDown(bloc.close);
    await tester.pumpWidget(_app(bloc, _tomato));
    await tester.tap(find.text('Find relevant knowledge'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('knowledge-empty')), findsOneWidget);

    repository.chunkError = const KnowledgeRetrievalFailure(
      KnowledgeRetrievalFailureType.network,
      'Check your connection and try again.',
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('knowledge-failure')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repository
      ..chunkError = null
      ..chunks = const KnowledgeDocuments(items: [sampleKnowledgeChunk]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('knowledge-loaded')), findsOneWidget);
  });
}

KnowledgeRetrievalBloc _bloc(FakeKnowledgeRepository repository) =>
    KnowledgeRetrievalBloc(
      repository,
      const PlantNameResolver(),
      const KnowledgeRanker(),
    );

Widget _app(
  KnowledgeRetrievalBloc bloc,
  Plant plant, {
  ExternalLinkOpener? opener,
  PlantObservation? observation,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: BlocProvider.value(
        value: bloc,
        child: KnowledgeRetrievalPanel(
          plant: plant,
          observation: observation ?? sampleObservation,
          openExternalLink: opener,
        ),
      ),
    ),
  ),
);

const _tomato = Plant(
  id: 'plant-1',
  commonName: 'Tomato',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.mature,
);

const _pumpkin = Plant(
  id: 'plant-1',
  commonName: 'Pumpkin',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.mature,
);

const _monstera = Plant(
  id: 'plant-1',
  commonName: 'Monstera',
  environment: PlantEnvironment.indoor,
  growingMedium: GrowingMedium.pot,
  sunlight: Sunlight.partial,
  growthStage: GrowthStage.mature,
);

final _withoutAi = PlantObservation(
  schemaVersion: sampleObservation.schemaVersion,
  plantVisible: sampleObservation.plantVisible,
  imageQuality: sampleObservation.imageQuality,
  possibleIdentification: const PossiblePlantIdentification(),
  affectedParts: sampleObservation.affectedParts,
  observations: sampleObservation.observations,
  distribution: sampleObservation.distribution,
  severity: sampleObservation.severity,
  followUp: sampleObservation.followUp,
);
