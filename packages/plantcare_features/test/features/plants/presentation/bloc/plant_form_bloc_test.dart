import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_form_bloc.dart';

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
    'rechecks the latest count and rejects a fourth Free plant',
    setUp: () => repository.plantCount = 3,
    build: () => PlantFormBloc(repository),
    act: (bloc) => bloc.add(const PlantFormSubmitted(draft: sampleDraft)),
    expect: () => const [
      PlantFormState(status: PlantFormStatus.submitting),
      PlantFormState(
        status: PlantFormStatus.plantLimitReached,
        errorMessage: PlantCapabilityPolicy.plantLimitMessage,
      ),
    ],
    verify: (_) {
      expect(repository.countPlantsCalls, 1);
      expect(repository.addCalls, 0);
    },
  );

  blocTest<PlantFormBloc, PlantFormState>(
    'verified Premium can create above the Free limit',
    setUp: () => repository.plantCount = 20,
    build: () => PlantFormBloc(
      repository,
      premiumAccess: () => const PremiumAccessSnapshot(
        userId: 'user-1',
        status: PremiumAccessStatus.active,
      ),
    ),
    act: (bloc) => bloc.add(const PlantFormSubmitted(draft: sampleDraft)),
    expect: () => const [
      PlantFormState(status: PlantFormStatus.submitting),
      PlantFormState(status: PlantFormStatus.created, plantId: 'new-plant'),
    ],
    verify: (_) => expect(repository.addCalls, 1),
  );

  blocTest<PlantFormBloc, PlantFormState>(
    'editing remains available to an over-limit Free account',
    setUp: () => repository.plantCount = 12,
    build: () => PlantFormBloc(repository),
    act: (bloc) => bloc.add(
      const PlantFormSubmitted(draft: sampleDraft, plantId: 'plant-1'),
    ),
    expect: () => const [
      PlantFormState(status: PlantFormStatus.submitting, plantId: 'plant-1'),
      PlantFormState(status: PlantFormStatus.updated, plantId: 'plant-1'),
    ],
    verify: (_) {
      expect(repository.countPlantsCalls, 0);
      expect(repository.updateCalls, 1);
    },
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
