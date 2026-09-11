import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_assessment_bloc.dart';

import '../../../helpers/fake_knowledge_repository.dart';
import '../../../helpers/fake_plant_diagnosis_dependencies.dart';
import '../../../helpers/fake_plant_observation_dependencies.dart';

void main() {
  late FakePlantObservationRepository observationRepository;
  late FakePlantDiagnosisRepository diagnosisRepository;
  late FakeKnowledgeRepository knowledgeRepository;
  late PlantHealthAssessmentBloc bloc;

  setUp(() {
    observationRepository = FakePlantObservationRepository();
    diagnosisRepository = FakePlantDiagnosisRepository();
    knowledgeRepository = FakeKnowledgeRepository();
    bloc = PlantHealthAssessmentBloc(
      observationRepository,
      diagnosisRepository,
      knowledgeRepository,
    );
  });

  tearDown(() async {
    await bloc.close();
    await observationRepository.close();
    await diagnosisRepository.close();
  });

  test('loads observation, latest diagnosis, and trusted sources', () async {
    bloc.add(
      const PlantHealthAssessmentWatchRequested('plant-1', 'observation-1'),
    );
    await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthAssessmentStatus.loading,
    );
    observationRepository.detailsController.add(
      sampleObservation.copyWith(id: 'observation-1'),
    );
    diagnosisRepository.diagnoses.add([sampleDiagnosis]);
    final loaded = await bloc.stream.firstWhere(
      (state) =>
          state.status == PlantHealthAssessmentStatus.loaded &&
          state.sources.isNotEmpty,
    );
    expect(loaded.observation!.id, 'observation-1');
    expect(loaded.diagnosis, sampleDiagnosis);
    expect(loaded.sources.single, sampleKnowledgeSource);
  });
}
