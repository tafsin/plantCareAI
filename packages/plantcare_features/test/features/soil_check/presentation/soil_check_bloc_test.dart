import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/soil_check.dart';
import 'package:plantcare_features/src/soil_check/presentation/bloc/soil_check_bloc.dart';
import 'package:plantcare_features/src/soil_check/presentation/bloc/soil_check_details_bloc.dart';
import 'package:plantcare_features/src/soil_check/presentation/bloc/soil_check_history_bloc.dart';

import '../../../helpers/fake_plant_repository.dart';
import '../../../helpers/fake_soil_check_dependencies.dart';

void main() {
  late FakePlantRepository plants;
  late FakeSoilCheckRepository checks;
  late _Knowledge knowledge;
  setUp(() {
    plants = FakePlantRepository();
    checks = FakeSoilCheckRepository();
    knowledge = _Knowledge();
  });
  tearDown(() async {
    await plants.close();
    await checks.close();
  });

  SoilCheckBloc create() => SoilCheckBloc(
    plants,
    checks,
    SoilEvidenceValidator(knowledge),
    DeterministicWateringEngine(),
  );

  blocTest<SoilCheckBloc, SoilCheckState>(
    'successful save validates evidence and stores recommendation',
    build: create,
    act: (bloc) async {
      bloc.add(const SoilCheckStarted('plant-1'));
      await _tick();
      plants.emitPlant('plant-1', _tomato);
      await _tick();
      bloc.add(const SoilCheckMoistureSelected(SoilMoistureLevel.dry));
      await _tick();
      bloc.add(SoilCheckSubmitted(checkTime: DateTime.utc(2026)));
    },
    verify: (_) {
      expect(checks.saveCalls, 1);
      expect(checks.savedRecord!.guidance.outcome, WateringOutcome.waterNow);
    },
  );

  blocTest<SoilCheckBloc, SoilCheckState>(
    'missing evidence rejects save',
    build: () {
      knowledge.missing = true;
      return create();
    },
    act: (bloc) async {
      bloc.add(const SoilCheckStarted('plant-1'));
      await _tick();
      plants.emitPlant('plant-1', _tomato);
      await _tick();
      bloc.add(const SoilCheckMoistureSelected(SoilMoistureLevel.dry));
      await _tick();
      bloc.add(SoilCheckSubmitted(checkTime: DateTime.utc(2026)));
    },
    verify: (bloc) {
      expect(checks.saveCalls, 0);
      expect(bloc.state.errorMessage, contains('missing'));
    },
  );

  blocTest<SoilCheckBloc, SoilCheckState>(
    'evidence mismatch rejects save',
    build: () {
      knowledge.mismatch = true;
      return create();
    },
    act: (bloc) async {
      bloc.add(const SoilCheckStarted('plant-1'));
      await _tick();
      plants.emitPlant('plant-1', _tomato);
      await _tick();
      bloc.add(const SoilCheckMoistureSelected(SoilMoistureLevel.dry));
      await _tick();
      bloc.add(SoilCheckSubmitted(checkTime: DateTime.utc(2026)));
    },
    verify: (bloc) {
      expect(checks.saveCalls, 0);
      expect(bloc.state.errorMessage, contains('does not match'));
    },
  );

  blocTest<SoilCheckBloc, SoilCheckState>(
    'persistence failure retains result and retry does not recalculate',
    build: () {
      checks.saveError = const SoilCheckFailure(
        SoilCheckFailureType.saveFailed,
        'no',
      );
      return create();
    },
    act: (bloc) async {
      bloc.add(const SoilCheckStarted('plant-1'));
      await _tick();
      plants.emitPlant('plant-1', _tomato);
      await _tick();
      bloc.add(const SoilCheckMoistureSelected(SoilMoistureLevel.dry));
      await _tick();
      bloc.add(SoilCheckSubmitted(checkTime: DateTime.utc(2026)));
      await _tick();
      checks.saveError = null;
      bloc.add(const SoilCheckSaveRetried());
    },
    verify: (bloc) {
      expect(checks.saveCalls, 2);
      expect(knowledge.chunkLoads, 1);
      expect(bloc.state.status, SoilCheckStatus.saved);
    },
  );

  blocTest<SoilCheckBloc, SoilCheckState>(
    'duplicate submission is ignored',
    build: create,
    act: (bloc) async {
      bloc.add(const SoilCheckStarted('plant-1'));
      await _tick();
      plants.emitPlant('plant-1', _tomato);
      await _tick();
      bloc.add(const SoilCheckMoistureSelected(SoilMoistureLevel.dry));
      await _tick();
      final event = SoilCheckSubmitted(checkTime: DateTime.utc(2026));
      bloc.add(event);
      bloc.add(event);
    },
    verify: (_) => expect(checks.saveCalls, 1),
  );

  blocTest<SoilCheckHistoryBloc, SoilCheckHistoryState>(
    'history supports loaded empty and retry after failure',
    build: () => SoilCheckHistoryBloc(checks),
    act: (bloc) async {
      bloc.add(const SoilCheckHistoryWatchRequested('plant-1'));
      await _tick();
      checks.history.addError(Exception());
      await _tick();
      bloc.add(const SoilCheckHistoryWatchRequested('plant-1'));
      await _tick();
      checks.history.add(const []);
    },
    verify: (bloc) {
      expect(bloc.state.status, SoilCheckHistoryStatus.loaded);
      expect(bloc.state.items, isEmpty);
    },
  );

  blocTest<SoilCheckDetailsBloc, SoilCheckDetailsState>(
    'details reports not found',
    build: () => SoilCheckDetailsBloc(checks),
    act: (bloc) async {
      bloc.add(const SoilCheckDetailsWatchRequested('plant-1', 'missing'));
      await _tick();
      checks.emitDetail('missing', null);
    },
    verify: (bloc) =>
        expect(bloc.state.status, SoilCheckDetailsStatus.notFound),
  );
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 1));

const _tomato = Plant(
  id: 'plant-1',
  commonName: 'Tomato',
  scientificName: 'Solanum lycopersicum',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.fruiting,
);

final class _Knowledge implements KnowledgeRepository {
  bool missing = false;
  bool mismatch = false;
  int chunkLoads = 0;
  @override
  Future<KnowledgeDocuments<KnowledgeChunk>> loadChunksForPlant(
    String key,
  ) async {
    chunkLoads++;
    if (missing) return const KnowledgeDocuments(items: []);
    return KnowledgeDocuments(
      items: [
        KnowledgeChunk(
          id: 'tomato__watering__consistent_deep_watering',
          canonicalPlantKey: mismatch ? 'pumpkin' : 'tomato',
          category: 'watering',
          environment: const ['outdoor'],
          affectedParts: const ['root'],
          growthStages: const ['mature'],
          symptomKeywords: const [],
          title: 'Watering',
          content: 'x' * 100,
          cautions: const [],
          sourceIds: const ['source'],
          datasetVersion: KnowledgeVersions.dataset,
        ),
      ],
    );
  }

  @override
  Future<KnowledgeDocuments<KnowledgeSource>> loadSources(
    Set<String> ids,
  ) async => const KnowledgeDocuments(
    items: [
      KnowledgeSource(
        id: 'source',
        title: 'Trusted',
        publisher: 'Extension',
        url: 'https://example.edu',
        datasetVersion: KnowledgeVersions.dataset,
      ),
    ],
  );
}
