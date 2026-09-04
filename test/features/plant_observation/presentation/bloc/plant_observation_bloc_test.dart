import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/selected_plant_image.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/plant_observation_bloc.dart';

import '../../../../helpers/fake_plant_observation_dependencies.dart';

const plantContext = PlantObservationContext(
  commonName: 'Tomato',
  scientificName: 'Solanum lycopersicum',
  environment: 'outdoor',
  growthStage: 'fruiting',
);

void main() {
  late FakePlantImagePicker picker;
  late FakePlantImageProcessor processor;
  late FakePlantObservationService service;
  late FakePlantObservationRepository repository;

  setUp(() {
    picker = FakePlantImagePicker();
    processor = FakePlantImageProcessor();
    service = FakePlantObservationService();
    repository = FakePlantObservationRepository();
  });

  tearDown(() => repository.close());

  PlantObservationBloc buildBloc() =>
      PlantObservationBloc(picker, processor, service, repository);

  blocTest<PlantObservationBloc, PlantObservationState>(
    'requires consent before analysis',
    build: buildBloc,
    seed: () => PlantObservationState(
      status: PlantObservationStatus.imageSelected,
      image: sampleSelectedImage,
    ),
    act: (bloc) => bloc.add(
      const PlantObservationAnalysisRequested(
        plantId: 'plant-1',
        context: plantContext,
      ),
    ),
    verify: (bloc) {
      expect(bloc.state.status, PlantObservationStatus.failure);
      expect(bloc.state.errorMessage, contains('privacy disclosure'));
      expect(service.calls, 0);
    },
  );

  blocTest<PlantObservationBloc, PlantObservationState>(
    'successfully analyzes structured output and persists it',
    build: buildBloc,
    seed: _readyState,
    act: (bloc) => bloc.add(
      const PlantObservationAnalysisRequested(
        plantId: 'plant-1',
        context: plantContext,
      ),
    ),
    wait: Duration.zero,
    verify: (bloc) {
      expect(bloc.state.status, PlantObservationStatus.success);
      expect(bloc.state.image, isNull);
      expect(bloc.state.result?.id, 'observation-1');
      expect(service.calls, 1);
      expect(repository.saveCalls, 1);
    },
  );

  for (final scenario in <String, PlantObservation>{
    'no-plant-visible result': const PlantObservation(
      schemaVersion: 1,
      plantVisible: false,
      imageQuality: ImageQuality(usable: true, issues: []),
      possibleIdentification: PossiblePlantIdentification(),
      affectedParts: [],
      observations: [],
      distribution: '',
      severity: ObservationSeverity.unclear,
      followUp: ObservationFollowUp(
        anotherPhotoHelpful: true,
        instruction: 'Photograph one plant clearly.',
      ),
    ),
    'unusable-image result': const PlantObservation(
      schemaVersion: 1,
      plantVisible: true,
      imageQuality: ImageQuality(
        usable: false,
        issues: [ObservationIssue.blurred],
      ),
      possibleIdentification: PossiblePlantIdentification(),
      affectedParts: [],
      observations: [],
      distribution: '',
      severity: ObservationSeverity.unclear,
      followUp: ObservationFollowUp(
        anotherPhotoHelpful: true,
        instruction: 'Take a sharper photo.',
      ),
    ),
  }.entries) {
    blocTest<PlantObservationBloc, PlantObservationState>(
      'preserves and saves ${scenario.key}',
      build: () {
        service.result = scenario.value;
        return buildBloc();
      },
      seed: _readyState,
      act: (bloc) => bloc.add(
        const PlantObservationAnalysisRequested(
          plantId: 'plant-1',
          context: plantContext,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.status, PlantObservationStatus.success);
        expect(bloc.state.result?.plantVisible, scenario.value.plantVisible);
        expect(
          bloc.state.result?.imageQuality.usable,
          scenario.value.imageQuality.usable,
        );
      },
    );
  }

  for (final scenario in <String, PlantObservationFailure>{
    'AI quota failure': const PlantObservationFailure(
      PlantObservationFailureType.quotaExceeded,
      'The free AI quota is currently unavailable. Try again later.',
    ),
    'network failure': const PlantObservationFailure(
      PlantObservationFailureType.network,
      'Check your connection and try again.',
    ),
    'malformed AI response': const PlantObservationFailure(
      PlantObservationFailureType.malformedResponse,
      'The observation response was not usable.',
    ),
  }.entries) {
    blocTest<PlantObservationBloc, PlantObservationState>(
      'maps ${scenario.key} without saving',
      build: () {
        service.error = scenario.value;
        return buildBloc();
      },
      seed: _readyState,
      act: (bloc) => bloc.add(
        const PlantObservationAnalysisRequested(
          plantId: 'plant-1',
          context: plantContext,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.status, PlantObservationStatus.failure);
        expect(bloc.state.errorMessage, scenario.value.message);
        expect(repository.saveCalls, 0);
      },
    );
  }

  test('prevents duplicate submissions while analysis is active', () async {
    service.completer = Completer<PlantObservation>();
    picker.result = PickedPlantImage(
      bytes: sampleSelectedImage.bytes,
      filename: 'plant.jpg',
    );
    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.add(const PlantObservationImageRequested(PlantImageSource.gallery));
    await bloc.stream.firstWhere(
      (state) => state.status == PlantObservationStatus.imageSelected,
    );
    bloc.add(const PlantObservationConsentChanged(true));
    await bloc.stream.firstWhere((state) => state.consented);

    const request = PlantObservationAnalysisRequested(
      plantId: 'plant-1',
      context: plantContext,
    );
    bloc
      ..add(request)
      ..add(request);
    await Future<void>.delayed(Duration.zero);
    expect(service.calls, 1);
    service.completer!.complete(sampleObservation);
    await bloc.stream.firstWhere(
      (state) => state.status == PlantObservationStatus.success,
    );
    expect(service.calls, 1);
  });

  blocTest<PlantObservationBloc, PlantObservationState>(
    'keeps the AI result visible and retries only persistence',
    build: () {
      repository.saveError = const PlantObservationFailure(
        PlantObservationFailureType.saveFailed,
        'The observation was created but could not be saved.',
      );
      return buildBloc();
    },
    seed: _readyState,
    act: (bloc) async {
      bloc.add(
        const PlantObservationAnalysisRequested(
          plantId: 'plant-1',
          context: plantContext,
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.status == PlantObservationStatus.saveFailure,
      );
      repository.saveError = null;
      bloc.add(const PlantObservationSaveRetried('plant-1'));
    },
    verify: (bloc) {
      expect(bloc.state.status, PlantObservationStatus.success);
      expect(service.calls, 1);
      expect(repository.saveCalls, 2);
      expect(bloc.state.result, isNotNull);
    },
  );
}

PlantObservationState _readyState() => PlantObservationState(
  status: PlantObservationStatus.imageSelected,
  image: sampleSelectedImage,
  consented: true,
);
