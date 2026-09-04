import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/errors/knowledge_retrieval_failure.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/knowledge_ranker.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

import '../../../helpers/fake_knowledge_repository.dart';
import '../../../helpers/fake_plant_observation_dependencies.dart';

void main() {
  late FakeKnowledgeRepository repository;
  late KnowledgeRetrievalBloc bloc;

  setUp(() {
    repository = FakeKnowledgeRepository();
    bloc = KnowledgeRetrievalBloc(
      repository,
      const PlantNameResolver(),
      const KnowledgeRanker(),
    );
  });

  tearDown(() => bloc.close());

  test('loads ranked chunks and only their required sources', () async {
    bloc.add(_request(_tomato));
    final state = await bloc.stream.firstWhere(
      (state) => state.status == KnowledgeRetrievalStatus.loaded,
    );
    expect(repository.requestedPlantKey, 'tomato');
    expect(repository.requestedSourceIds, {'extension_source'});
    expect(state.result!.rankedMatches.single.sources, [sampleKnowledgeSource]);
  });

  test('unsupported plant does not query Firestore', () async {
    bloc.add(_request(_monstera, observation: _withoutAi));
    final state = await bloc.stream.firstWhere(
      (state) => state.status == KnowledgeRetrievalStatus.unsupportedPlant,
    );
    expect(state.status, KnowledgeRetrievalStatus.unsupportedPlant);
    expect(repository.chunkCalls, 0);
  });

  test('candidate conflict waits for a local user selection', () async {
    bloc.add(
      const KnowledgeRetrievalRequested(
        plant: _pumpkin,
        observation: sampleObservation,
      ),
    );
    final conflict = await bloc.stream.first;
    expect(conflict.status, KnowledgeRetrievalStatus.candidateConflict);
    expect(repository.chunkCalls, 0);

    bloc.add(const KnowledgePlantCandidateSelected('tomato'));
    await bloc.stream.firstWhere(
      (state) => state.status == KnowledgeRetrievalStatus.loaded,
    );
    expect(repository.requestedPlantKey, 'tomato');
  });

  test(
    'empty query and below-threshold chunks produce no-strong-match',
    () async {
      repository.chunks = const KnowledgeDocuments(items: []);
      bloc.add(_request(_tomato));
      final state = await bloc.stream.firstWhere(
        (state) => state.status == KnowledgeRetrievalStatus.noStrongMatch,
      );
      expect(state.result!.rankedMatches, isEmpty);
      expect(repository.sourceCalls, 0);
    },
  );

  test('missing source is a warning and does not discard the match', () async {
    repository.sources = const KnowledgeDocuments(items: []);
    bloc.add(_request(_tomato));
    final state = await bloc.stream.firstWhere(
      (state) => state.status == KnowledgeRetrievalStatus.loaded,
    );
    expect(state.result!.rankedMatches.single.sources, isEmpty);
    expect(state.result!.warnings.single, contains('extension_source'));
  });

  test('permission and network errors become safe failure states', () async {
    for (final failure in const [
      KnowledgeRetrievalFailure(
        KnowledgeRetrievalFailureType.permissionDenied,
        'No permission.',
      ),
      KnowledgeRetrievalFailure(
        KnowledgeRetrievalFailureType.network,
        'Check your connection and try again.',
      ),
    ]) {
      repository.chunkError = failure;
      bloc.add(_request(_tomato));
      final state = await bloc.stream.firstWhere(
        (state) => state.status == KnowledgeRetrievalStatus.failure,
      );
      expect(state.errorMessage, failure.message);
      repository.chunkError = null;
    }
  });

  test('prevents duplicate retrieval while one is running', () async {
    final completer = Completer<KnowledgeDocuments<KnowledgeChunk>>();
    repository.chunkCompleter = completer;
    final request = _request(_tomato);
    bloc
      ..add(request)
      ..add(request);
    await bloc.stream.firstWhere(
      (state) => state.status == KnowledgeRetrievalStatus.loading,
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.chunkCalls, 1);
    completer.complete(repository.chunks);
    await bloc.stream.firstWhere(
      (state) => state.status == KnowledgeRetrievalStatus.loaded,
    );
  });

  test('retry repeats a failed selected retrieval', () async {
    repository.chunkError = const KnowledgeRetrievalFailure(
      KnowledgeRetrievalFailureType.network,
      'Offline.',
    );
    bloc.add(_request(_tomato));
    await bloc.stream.firstWhere(
      (state) => state.status == KnowledgeRetrievalStatus.failure,
    );
    repository.chunkError = null;
    bloc.add(const KnowledgeRetrievalRetryRequested());
    await bloc.stream.firstWhere(
      (state) => state.status == KnowledgeRetrievalStatus.loaded,
    );
    expect(repository.chunkCalls, 2);
  });
}

KnowledgeRetrievalRequested _request(
  Plant plant, {
  PlantObservation? observation,
}) => KnowledgeRetrievalRequested(
  plant: plant,
  observation: observation ?? sampleObservation,
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

const _tomato = Plant(
  id: 'plant-1',
  commonName: 'Tomato',
  scientificName: 'Solanum lycopersicum',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.mature,
);

const _pumpkin = Plant(
  id: 'plant-1',
  commonName: 'Pumpkin',
  scientificName: 'Cucurbita pepo',
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
