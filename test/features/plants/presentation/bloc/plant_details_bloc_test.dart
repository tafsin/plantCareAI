import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';

import '../../../../helpers/fake_plant_repository.dart';
import '../../plant_test_data.dart';

void main() {
  test('shows loaded and not-found states from the plant stream', () async {
    final repository = FakePlantRepository();
    final bloc = PlantDetailsBloc(repository);
    addTearDown(() async {
      await bloc.close();
      await repository.close();
    });

    bloc.add(const PlantDetailsWatchRequested('plant-1'));
    await Future<void>.delayed(Duration.zero);
    repository.emitPlant('plant-1', samplePlant);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, PlantDetailsStatus.loaded);

    repository.emitPlant('plant-1', null);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, PlantDetailsStatus.notFound);
  });
}
