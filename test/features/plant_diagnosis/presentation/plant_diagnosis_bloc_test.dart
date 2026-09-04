import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/plant_diagnosis_bloc.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';

import '../../../helpers/fake_knowledge_repository.dart';
import '../../../helpers/fake_plant_diagnosis_dependencies.dart';
import '../../../helpers/fake_plant_observation_dependencies.dart';

void main() {
  late FakeKnowledgeRepository knowledge;
  late FakePlantDiagnosisRepository repository;
  late FakePlantDiagnosisService service;
  late PlantDiagnosisBloc bloc;

  setUp(() {
    knowledge = FakeKnowledgeRepository();
    repository = FakePlantDiagnosisRepository();
    service = FakePlantDiagnosisService()..response = sampleDiagnosis;
    bloc = PlantDiagnosisBloc(
      knowledge,
      repository,
      service,
      const PlantNameResolver(),
      const KnowledgeRanker(),
    );
  });

  tearDown(() async {
    await bloc.close();
    await repository.close();
  });

  test('retrieves, passes exact context, generates, and persists', () async {
    bloc.add(_request(_tomato));
    final result = await bloc.stream.firstWhere(
      (state) => state.status == PlantDiagnosisStatus.success,
    );
    expect(service.calls, 1);
    expect(service.request!.plant, _tomato);
    expect(service.request!.observation, sampleObservation);
    expect(
      service.request!.retrieval.rankedMatches.single.chunk,
      sampleKnowledgeChunk,
    );
    expect(repository.saved, sampleDiagnosis);
    expect(result.diagnosisId, 'diagnosis-1');
  });

  test('no relevant evidence never calls Gemini', () async {
    knowledge.chunks = const KnowledgeDocuments(items: []);
    bloc.add(_request(_tomato));
    await bloc.stream.firstWhere(
      (state) => state.status == PlantDiagnosisStatus.insufficientEvidence,
    );
    expect(service.calls, 0);
  });

  test('unsupported plant never retrieves or calls Gemini', () async {
    bloc.add(_request(_monstera, observation: _withoutAi));
    await bloc.stream.firstWhere(
      (state) => state.status == PlantDiagnosisStatus.failure,
    );
    expect(knowledge.chunkCalls, 0);
    expect(service.calls, 0);
  });

  test('conflict requires explicit selection', () async {
    bloc.add(_request(_pumpkin));
    final conflict = await bloc.stream.firstWhere(
      (state) => state.status == PlantDiagnosisStatus.conflictSelectionRequired,
    );
    expect(conflict.candidates, containsAll(['pumpkin', 'tomato']));
    expect(service.calls, 0);
    bloc.add(const DiagnosisPlantCandidateSelected('tomato'));
    await bloc.stream.firstWhere(
      (state) => state.status == PlantDiagnosisStatus.success,
    );
    expect(service.calls, 1);
  });

  test('duplicate requests are ignored while retrieval is in flight', () async {
    final completer = Completer<KnowledgeDocuments<KnowledgeChunk>>();
    knowledge.chunkCompleter = completer;
    final request = _request(_tomato);
    bloc
      ..add(request)
      ..add(request);
    await bloc.stream.firstWhere(
      (state) => state.status == PlantDiagnosisStatus.retrievingEvidence,
    );
    await Future<void>.delayed(Duration.zero);
    expect(knowledge.chunkCalls, 1);
    completer.complete(knowledge.chunks);
    await bloc.stream.firstWhere(
      (state) => state.status == PlantDiagnosisStatus.success,
    );
  });

  test(
    'save failure keeps result and retry-save does not call Gemini',
    () async {
      repository.saveError = const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.saveFailed,
        'Save failed.',
      );
      bloc.add(_request(_tomato));
      final failure = await bloc.stream.firstWhere(
        (state) => state.status == PlantDiagnosisStatus.failure,
      );
      expect(failure.diagnosis, sampleDiagnosis);
      expect(failure.saveRetryAvailable, isTrue);
      repository.saveError = null;
      bloc.add(const PlantDiagnosisSaveRetryRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == PlantDiagnosisStatus.success,
      );
      expect(service.calls, 1);
      expect(repository.saveCalls, 2);
    },
  );
}

PlantDiagnosisRequested _request(
  Plant plant, {
  PlantObservation? observation,
}) => PlantDiagnosisRequested(
  plantId: plant.id,
  observationId: 'observation-1',
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
