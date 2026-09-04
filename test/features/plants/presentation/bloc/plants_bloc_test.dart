import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/plants/domain/errors/plant_failure.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plants_bloc.dart';

import '../../../../helpers/fake_plant_repository.dart';
import '../../plant_test_data.dart';

void main() {
  late FakePlantRepository repository;
  late PlantsBloc bloc;

  setUp(() {
    repository = FakePlantRepository();
    bloc = PlantsBloc(repository);
  });
  tearDown(() async {
    await bloc.close();
    await repository.close();
  });

  test('watches empty and populated collections', () async {
    bloc.add(const PlantsWatchRequested());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, PlantsStatus.loading);

    repository.emitPlants([]);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, PlantsStatus.empty);

    repository.emitPlants([samplePlant]);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, PlantsStatus.loaded);
    expect(bloc.state.plants, [samplePlant]);
  });

  test('shows a stream failure and retries', () async {
    repository.watchPlantsError = const PlantFailure(
      PlantFailureType.network,
      'Check your connection and try again.',
    );
    bloc.add(const PlantsWatchRequested());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, PlantsStatus.failure);

    repository.watchPlantsError = null;
    bloc.add(const PlantsWatchRequested());
    await Future<void>.delayed(Duration.zero);
    repository.emitPlants([samplePlant]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.watchPlantsCalls, 2);
    expect(bloc.state.status, PlantsStatus.loaded);
  });

  test('reports successful deletion without optimistic removal', () async {
    bloc.add(PlantsChanged([samplePlant]));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PlantDeleteRequested('plant-1'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.deleteCalls, 1);
    expect(bloc.state.deletedPlantId, 'plant-1');
    expect(bloc.state.plants, [samplePlant]);
  });

  test('preserves plants and reports failed deletion', () async {
    repository.deleteError = const PlantFailure(
      PlantFailureType.network,
      'Check your connection and try again.',
    );
    bloc.add(PlantsChanged([samplePlant]));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PlantDeleteRequested('plant-1'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.deleteFailureMessage, isNotNull);
    expect(bloc.state.plants, [samplePlant]);
    expect(bloc.state.deletingPlantIds, isEmpty);
  });
}
