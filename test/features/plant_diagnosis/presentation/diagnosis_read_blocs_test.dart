import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/diagnosis_details_bloc.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/diagnosis_history_bloc.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';

import '../../../helpers/fake_knowledge_repository.dart';
import '../../../helpers/fake_plant_diagnosis_dependencies.dart';

void main() {
  late FakePlantDiagnosisRepository repository;

  setUp(() => repository = FakePlantDiagnosisRepository());
  tearDown(() => repository.close());

  test('history supports empty, loaded, failure, and retry', () async {
    final bloc = DiagnosisHistoryBloc(repository)
      ..add(const DiagnosisHistoryWatchRequested('plant-1', 'observation-1'));
    await bloc.stream.firstWhere(
      (state) => state.status == DiagnosisHistoryStatus.loading,
    );
    repository.diagnoses.add(const []);
    expect(
      (await bloc.stream.firstWhere(
        (state) => state.status == DiagnosisHistoryStatus.loaded,
      )).items,
      isEmpty,
    );
    repository.diagnoses.add([sampleDiagnosis]);
    expect(
      (await bloc.stream.firstWhere((state) => state.items.isNotEmpty))
          .items
          .single,
      sampleDiagnosis,
    );
    repository.diagnoses.addError(
      const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.network,
        'Offline.',
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state.status == DiagnosisHistoryStatus.failure,
    );
    bloc.add(const DiagnosisHistoryWatchRequested('plant-1', 'observation-1'));
    await bloc.stream.firstWhere(
      (state) => state.status == DiagnosisHistoryStatus.loading,
    );
    await bloc.close();
  });

  test('details reports not found and resolves trusted sources', () async {
    final knowledge = FakeKnowledgeRepository();
    final bloc = DiagnosisDetailsBloc(repository, knowledge)
      ..add(
        const DiagnosisDetailsWatchRequested(
          'plant-1',
          'observation-1',
          'diagnosis-1',
        ),
      );
    await bloc.stream.firstWhere(
      (state) => state.status == DiagnosisDetailsStatus.loading,
    );
    repository.details.add(null);
    await bloc.stream.firstWhere(
      (state) => state.status == DiagnosisDetailsStatus.notFound,
    );
    repository.details.add(sampleDiagnosis);
    final loaded = await bloc.stream.firstWhere(
      (state) => state.status == DiagnosisDetailsStatus.loaded,
    );
    expect(loaded.sources, [sampleKnowledgeSource]);
    expect(knowledge.requestedSourceIds, {'extension_source'});
    await bloc.close();
  });
}
