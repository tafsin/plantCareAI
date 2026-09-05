import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/src/fertilizer_assessment/presentation/bloc/fertilizer_assessment_bloc.dart';
import 'package:plantcare_features/src/fertilizer_assessment/presentation/bloc/fertilizer_assessment_details_bloc.dart';
import 'package:plantcare_features/src/fertilizer_assessment/presentation/bloc/fertilizer_assessment_history_bloc.dart';

import '../../../helpers/fake_care_log_dependencies.dart';
import '../../../helpers/fake_fertilizer_assessment_repository.dart';
import '../../../helpers/fake_plant_repository.dart';

void main() {
  late FakePlantRepository plants;
  late FakeCareLogRepository care;
  late FakeFertilizerAssessmentRepository assessments;
  late _Knowledge knowledge;

  setUp(() {
    plants = FakePlantRepository();
    care = FakeCareLogRepository();
    assessments = FakeFertilizerAssessmentRepository();
    knowledge = _Knowledge();
  });
  tearDown(() async {
    await plants.close();
    await care.close();
    await assessments.close();
  });

  FertilizerAssessmentBloc create() => FertilizerAssessmentBloc(
    plants,
    care,
    assessments,
    FertilizerEvidenceValidator(knowledge),
    DeterministicFertilizerEngine(),
  );

  Future<void> load(
    FertilizerAssessmentBloc bloc, {
    List<CareLog> logs = const [],
  }) async {
    bloc.add(const FertilizerAssessmentStarted('plant-1'));
    await _tick();
    plants.emitPlant('plant-1', _tomato);
    care.history.add(logs);
    await _tick();
  }

  blocTest<FertilizerAssessmentBloc, FertilizerAssessmentState>(
    'uses latest fertilizer care log and saves only after v2 evidence validation',
    build: create,
    act: (bloc) async {
      await load(
        bloc,
        logs: [
          FertilizingLog(
            id: 'old',
            occurredAt: DateTime.utc(2026, 1),
            fertilizerForm: FertilizerForm.compost,
          ),
          FertilizingLog(
            id: 'new',
            occurredAt: DateTime.utc(2026, 8),
            fertilizerForm: FertilizerForm.liquid,
          ),
        ],
      );
      bloc.add(
        const FertilizerGrowthActivitySelected(GrowthActivity.activeGrowth),
      );
      await _tick();
      bloc.add(
        FertilizerAssessmentSubmitted(assessmentTime: DateTime.utc(2026, 9, 3)),
      );
    },
    verify: (bloc) {
      expect(bloc.state.lastFertilizingLog?.id, 'new');
      expect(assessments.saveCalls, 1);
      expect(
        assessments.savedAssessment!.guidance.datasetVersion,
        '2026-09-03-v2',
      );
      expect(knowledge.chunkLoads, 1);
    },
  );

  blocTest<FertilizerAssessmentBloc, FertilizerAssessmentState>(
    'missing evidence blocks persistence',
    build: () {
      knowledge.missing = true;
      return create();
    },
    act: (bloc) async {
      await load(bloc);
      bloc.add(
        const FertilizerGrowthActivitySelected(GrowthActivity.activeGrowth),
      );
      await _tick();
      bloc.add(
        FertilizerAssessmentSubmitted(assessmentTime: DateTime.utc(2026, 9, 3)),
      );
    },
    verify: (bloc) {
      expect(assessments.saveCalls, 0);
      expect(bloc.state.errorMessage, contains('missing'));
    },
  );

  blocTest<FertilizerAssessmentBloc, FertilizerAssessmentState>(
    'retry saves retained result without recalculating or revalidating',
    build: () {
      assessments.saveError = Exception('offline');
      return create();
    },
    act: (bloc) async {
      await load(bloc);
      bloc.add(
        const FertilizerGrowthActivitySelected(GrowthActivity.activeGrowth),
      );
      await _tick();
      bloc.add(
        FertilizerAssessmentSubmitted(assessmentTime: DateTime.utc(2026, 9, 3)),
      );
      await _tick();
      assessments.saveError = null;
      bloc.add(const FertilizerAssessmentSaveRetried());
    },
    verify: (bloc) {
      expect(assessments.saveCalls, 2);
      expect(knowledge.chunkLoads, 1);
      expect(bloc.state.status, FertilizerAssessmentStatus.saved);
    },
  );

  blocTest<FertilizerAssessmentBloc, FertilizerAssessmentState>(
    'mismatched v1 evidence blocks persistence',
    build: () {
      knowledge.mismatch = true;
      return create();
    },
    act: (bloc) async {
      await load(bloc);
      bloc.add(
        const FertilizerGrowthActivitySelected(GrowthActivity.activeGrowth),
      );
      await _tick();
      bloc.add(
        FertilizerAssessmentSubmitted(assessmentTime: DateTime.utc(2026, 9, 3)),
      );
    },
    verify: (bloc) {
      expect(assessments.saveCalls, 0);
      expect(bloc.state.errorMessage, contains('does not match'));
    },
  );

  blocTest<FertilizerAssessmentBloc, FertilizerAssessmentState>(
    'unsupported plant is not persisted',
    build: create,
    act: (bloc) async {
      bloc.add(const FertilizerAssessmentStarted('plant-1'));
      await _tick();
      plants.emitPlant('plant-1', _unsupported);
      care.history.add(const []);
      await _tick();
      bloc.add(
        const FertilizerGrowthActivitySelected(GrowthActivity.activeGrowth),
      );
      await _tick();
      bloc.add(
        FertilizerAssessmentSubmitted(assessmentTime: DateTime.utc(2026, 9, 3)),
      );
    },
    verify: (bloc) {
      expect(bloc.state.status, FertilizerAssessmentStatus.unsupportedPlant);
      expect(assessments.saveCalls, 0);
    },
  );

  blocTest<FertilizerAssessmentBloc, FertilizerAssessmentState>(
    'duplicate submission is ignored',
    build: create,
    act: (bloc) async {
      await load(bloc);
      bloc.add(
        const FertilizerGrowthActivitySelected(GrowthActivity.activeGrowth),
      );
      await _tick();
      final event = FertilizerAssessmentSubmitted(
        assessmentTime: DateTime.utc(2026, 9, 3),
      );
      bloc.add(event);
      bloc.add(event);
    },
    verify: (_) => expect(assessments.saveCalls, 1),
  );

  blocTest<FertilizerAssessmentHistoryBloc, FertilizerAssessmentHistoryState>(
    'history supports an empty loaded state',
    build: () => FertilizerAssessmentHistoryBloc(assessments),
    act: (bloc) async {
      bloc.add(const FertilizerAssessmentHistoryWatchRequested('plant-1'));
      await _tick();
      assessments.history.add(const []);
    },
    verify: (bloc) {
      expect(bloc.state.status, FertilizerAssessmentHistoryStatus.loaded);
      expect(bloc.state.items, isEmpty);
    },
  );

  blocTest<FertilizerAssessmentDetailsBloc, FertilizerAssessmentDetailsState>(
    'details supports the not-found state',
    build: () => FertilizerAssessmentDetailsBloc(
      assessments,
      FertilizerEvidenceValidator(knowledge),
    ),
    act: (bloc) async {
      bloc.add(
        const FertilizerAssessmentDetailsWatchRequested('plant-1', 'missing'),
      );
      await _tick();
      assessments.emitDetail('missing', null);
    },
    verify: (bloc) =>
        expect(bloc.state.status, FertilizerAssessmentDetailsStatus.notFound),
  );
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 2));

const _tomato = Plant(
  id: 'plant-1',
  commonName: 'Tomato',
  scientificName: 'Solanum lycopersicum',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.fruiting,
);

const _unsupported = Plant(
  id: 'plant-1',
  commonName: 'Rose',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.flowering,
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
          id: 'tomato__nutrient_guidance__fertilizer_soil_test_and_fruiting',
          canonicalPlantKey: 'tomato',
          category: 'nutrient_guidance',
          environment: ['outdoor'],
          affectedParts: ['whole_plant'],
          growthStages: ['fruiting'],
          symptomKeywords: [],
          title: 'Tomato fertilizer',
          content: 'Reviewed evidence content long enough for the production codec requirements.',
          cautions: [],
          sourceIds: ['source'],
          datasetVersion: mismatch
              ? '2026-09-03-v1'
              : KnowledgeVersions.dataset,
        ),
        KnowledgeChunk(
          id: 'tomato__nutrient_guidance__fertilizer_wait_while_stressed',
          canonicalPlantKey: 'tomato',
          category: 'nutrient_guidance',
          environment: ['outdoor'],
          affectedParts: ['whole_plant'],
          growthStages: ['fruiting'],
          symptomKeywords: [],
          title: 'Tomato stress',
          content: 'Reviewed evidence content long enough for the production codec requirements.',
          cautions: [],
          sourceIds: ['source'],
          datasetVersion: mismatch
              ? '2026-09-03-v1'
              : KnowledgeVersions.dataset,
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
        title: 'Trusted source',
        publisher: 'Extension',
        url: 'https://example.edu',
        datasetVersion: KnowledgeVersions.dataset,
      ),
    ],
  );
}
