import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_features/src/plant_observation/presentation/bloc/observation_history_bloc.dart';

import '../../../../helpers/fake_plant_observation_dependencies.dart';

void main() {
  late FakePlantObservationRepository repository;
  late ObservationHistoryBloc bloc;

  setUp(() async {
    repository = FakePlantObservationRepository();
    bloc = ObservationHistoryBloc(repository);
    bloc.add(const ObservationHistoryWatchRequested('plant-1'));
    await bloc.stream.firstWhere(
      (state) => state.status == ObservationHistoryStatus.loading,
    );
  });

  tearDown(() async {
    await bloc.close();
    await repository.close();
  });

  test('supports the observation history empty state', () async {
    repository.historyController.add(const []);
    final state = await bloc.stream.firstWhere(
      (state) => state.status == ObservationHistoryStatus.loaded,
    );
    expect(state.observations, isEmpty);
  });

  test('supports the observation history loaded state', () async {
    repository.historyController.add([
      sampleObservation.copyWith(id: 'observation-1'),
    ]);
    final state = await bloc.stream.firstWhere(
      (state) => state.status == ObservationHistoryStatus.loaded,
    );
    expect(state.observations.single.id, 'observation-1');
  });

  test('supports failure and retry', () async {
    repository.historyController.addError(
      const PlantObservationFailure(
        PlantObservationFailureType.network,
        'Check your connection and try again.',
      ),
    );
    final failed = await bloc.stream.firstWhere(
      (state) => state.status == ObservationHistoryStatus.failure,
    );
    expect(failed.errorMessage, contains('connection'));

    bloc.add(const ObservationHistoryWatchRequested('plant-1'));
    repository.historyController.add(const []);
    final recovered = await bloc.stream.firstWhere(
      (state) => state.status == ObservationHistoryStatus.loaded,
    );
    expect(recovered.observations, isEmpty);
  });
}
