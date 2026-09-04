import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_form_bloc.dart';
import 'package:plantcare_domain/plants.dart';

import '../../../../helpers/fake_plant_repository.dart';
import '../../plant_test_data.dart';

void main() {
  late FakePlantRepository repository;
  setUp(() => repository = FakePlantRepository());
  tearDown(() => repository.close());

  blocTest<PlantFormBloc, PlantFormState>(
    'creates a valid plant',
    build: () => PlantFormBloc(repository),
    act: (bloc) => bloc.add(const PlantFormSubmitted(draft: sampleDraft)),
    expect: () => const [
      PlantFormState(status: PlantFormStatus.submitting),
      PlantFormState(status: PlantFormStatus.created, plantId: 'new-plant'),
    ],
  );

  blocTest<PlantFormBloc, PlantFormState>(
    'reports failed creation',
    setUp: () => repository.addError = const PlantFailure(
      PlantFailureType.network,
      'Check your connection and try again.',
    ),
    build: () => PlantFormBloc(repository),
    act: (bloc) => bloc.add(const PlantFormSubmitted(draft: sampleDraft)),
    expect: () => const [
      PlantFormState(status: PlantFormStatus.submitting),
      PlantFormState(
        status: PlantFormStatus.failure,
        errorMessage: 'Check your connection and try again.',
      ),
    ],
  );

  blocTest<PlantFormBloc, PlantFormState>(
    'updates a valid plant',
    build: () => PlantFormBloc(repository),
    act: (bloc) => bloc.add(
      const PlantFormSubmitted(draft: sampleDraft, plantId: 'plant-1'),
    ),
    expect: () => const [
      PlantFormState(status: PlantFormStatus.submitting, plantId: 'plant-1'),
      PlantFormState(status: PlantFormStatus.updated, plantId: 'plant-1'),
    ],
    verify: (_) => expect(repository.updateCalls, 1),
  );

  blocTest<PlantFormBloc, PlantFormState>(
    'rejects invalid form data without writing',
    build: () => PlantFormBloc(repository),
    act: (bloc) => bloc.add(
      const PlantFormSubmitted(
        draft: PlantDraft(
          commonName: '',
          environment: PlantEnvironment.indoor,
          growingMedium: GrowingMedium.pot,
          sunlight: Sunlight.low,
          growthStage: GrowthStage.seedling,
        ),
      ),
    ),
    expect: () => const [
      PlantFormState(
        status: PlantFormStatus.failure,
        errorMessage: 'Enter a common name.',
      ),
    ],
    verify: (_) => expect(repository.addCalls, 0),
  );
}
