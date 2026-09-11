import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_history_bloc.dart';

import '../../../helpers/fake_plant_diagnosis_dependencies.dart';
import '../../../helpers/fake_plant_observation_dependencies.dart';

void main() {
  late FakePlantObservationRepository observationRepository;
  late _DiagnosisRepository diagnosisRepository;
  late PlantHealthHistoryBloc bloc;

  setUp(() {
    observationRepository = FakePlantObservationRepository();
    diagnosisRepository = _DiagnosisRepository();
    bloc = PlantHealthHistoryBloc(observationRepository, diagnosisRepository);
  });

  tearDown(() async {
    await bloc.close();
    await observationRepository.close();
    await diagnosisRepository.close();
  });

  test('combines historical observations with and without diagnoses', () async {
    bloc.add(const PlantHealthHistoryWatchRequested('plant-1'));
    await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthHistoryStatus.loading,
    );
    observationRepository.historyController.add([
      sampleObservation.copyWith(id: 'observation-1'),
      sampleObservation.copyWith(id: 'observation-2'),
    ]);
    diagnosisRepository.emit('observation-1', [sampleDiagnosis]);
    final loaded = await bloc.stream.firstWhere(
      (state) =>
          state.status == PlantHealthHistoryStatus.loaded &&
          state.entries.length == 2 &&
          state.entries.first.latestDiagnosis != null,
    );
    expect(
      loaded.entries.first.assessmentState,
      PlantHealthHistoryAssessmentState.needsAnotherPhoto,
    );
    expect(
      loaded.entries.last.assessmentState,
      PlantHealthHistoryAssessmentState.incomplete,
    );
  });
}

final class _DiagnosisRepository implements PlantDiagnosisRepository {
  final _controllers = <String, StreamController<List<PlantDiagnosis>>>{};

  void emit(String observationId, List<PlantDiagnosis> items) {
    _controllers[observationId]?.add(items);
  }

  @override
  Future<String> saveDiagnosis(
    String plantId,
    String observationId,
    PlantDiagnosis diagnosis,
  ) {
    throw UnimplementedError();
  }

  @override
  Stream<List<PlantDiagnosis>> watchDiagnoses(
    String plantId,
    String observationId,
  ) {
    return _controllers
        .putIfAbsent(
          observationId,
          () => StreamController<List<PlantDiagnosis>>.broadcast(sync: true),
        )
        .stream;
  }

  @override
  Stream<PlantDiagnosis?> watchDiagnosis(
    String plantId,
    String observationId,
    String diagnosisId,
  ) {
    throw UnimplementedError();
  }

  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
