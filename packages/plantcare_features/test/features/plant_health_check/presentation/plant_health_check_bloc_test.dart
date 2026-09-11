import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_check_bloc.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/pages/plant_health_check_page.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_details_bloc.dart';

import '../../../helpers/fake_knowledge_repository.dart';
import '../../../helpers/fake_local_plant_image_repository.dart';
import '../../../helpers/fake_plant_diagnosis_dependencies.dart';
import '../../../helpers/fake_plant_observation_dependencies.dart';
import '../../../helpers/fake_plant_repository.dart';

void main() {
  late FakePlantImagePicker picker;
  late FakePlantImageProcessor processor;
  late FakePlantObservationService observationService;
  late FakePlantObservationRepository observationRepository;
  late FakeKnowledgeRepository knowledgeRepository;
  late FakePlantDiagnosisService diagnosisService;
  late FakePlantDiagnosisRepository diagnosisRepository;
  late PlantHealthCheckBloc bloc;
  late FakeLocalPlantImageRepository localImages;

  setUp(() {
    picker = FakePlantImagePicker()
      ..result = PickedPlantImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'plant.jpg',
      );
    processor = FakePlantImageProcessor()
      ..result = SelectedPlantImage(
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
        mimeType: 'image/jpeg',
        filename: 'plant-analysis.jpg',
      );
    observationService = FakePlantObservationService();
    observationRepository = FakePlantObservationRepository();
    knowledgeRepository = FakeKnowledgeRepository();
    diagnosisService = FakePlantDiagnosisService()..response = sampleDiagnosis;
    diagnosisRepository = FakePlantDiagnosisRepository();
    localImages = FakeLocalPlantImageRepository();
    bloc = PlantHealthCheckBloc(
      picker,
      processor,
      observationService,
      observationRepository,
      knowledgeRepository,
      diagnosisRepository,
      diagnosisService,
      const PlantNameResolver(),
      const KnowledgeRanker(),
      localImages,
    );
  });

  tearDown(() async {
    await bloc.close();
    await observationRepository.close();
    await diagnosisRepository.close();
  });

  test('runs the complete health-check orchestration once', () async {
    await _select(bloc);
    bloc.add(
      const PlantHealthCheckAnalysisRequested(
        plantId: 'plant-1',
        plant: _tomato,
      ),
    );
    final result = await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthCheckStatus.complete,
    );
    expect(observationService.calls, 1);
    expect(observationRepository.saveCalls, 1);
    expect(knowledgeRepository.chunkCalls, 1);
    expect(diagnosisService.calls, 1);
    expect(diagnosisRepository.saveCalls, 1);
    expect(result.observationId, 'observation-1');
    expect(result.diagnosisId, 'diagnosis-1');
    expect(result.hasImage, isFalse);
    expect(localImages.saveCalls, 1);
    expect(localImages.images.single.observationId, 'observation-1');
  });

  test('does not save when no plant is visible', () async {
    observationService.result = _noPlantVisible;
    await _select(bloc);
    bloc.add(
      const PlantHealthCheckAnalysisRequested(
        plantId: 'plant-1',
        plant: _tomato,
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthCheckStatus.photoRejected,
    );
    expect(observationRepository.saveCalls, 0);
    expect(diagnosisService.calls, 0);
  });

  test('does not save when the photo is unusable', () async {
    observationService.result = _unusablePhoto;
    await _select(bloc);
    bloc.add(
      const PlantHealthCheckAnalysisRequested(
        plantId: 'plant-1',
        plant: _tomato,
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthCheckStatus.photoRejected,
    );
    expect(observationRepository.saveCalls, 0);
    expect(diagnosisService.calls, 0);
  });

  test(
    'evidence unavailable saves findings but does not call diagnosis AI',
    () async {
      knowledgeRepository.chunks = const KnowledgeDocuments(items: []);
      await _select(bloc);
      bloc.add(
        const PlantHealthCheckAnalysisRequested(
          plantId: 'plant-1',
          plant: _tomato,
        ),
      );
      final state = await bloc.stream.firstWhere(
        (state) => state.status == PlantHealthCheckStatus.insufficientEvidence,
      );
      expect(observationRepository.saveCalls, 1);
      expect(diagnosisService.calls, 0);
      expect(state.observationId, 'observation-1');
    },
  );

  test(
    'duplicate submissions are ignored while observation is in flight',
    () async {
      final completer = Completer<PlantObservation>();
      observationService.completer = completer;
      await _select(bloc);
      const request = PlantHealthCheckAnalysisRequested(
        plantId: 'plant-1',
        plant: _tomato,
      );
      bloc
        ..add(request)
        ..add(request);
      await bloc.stream.firstWhere(
        (state) => state.status == PlantHealthCheckStatus.observing,
      );
      await Future<void>.delayed(Duration.zero);
      expect(observationService.calls, 1);
      completer.complete(sampleObservation);
      await bloc.stream.firstWhere(
        (state) => state.status == PlantHealthCheckStatus.complete,
      );
    },
  );

  test('diagnosis save retry does not call diagnosis AI again', () async {
    diagnosisRepository.saveError = const PlantDiagnosisFailure(
      PlantDiagnosisFailureType.saveFailed,
      'Save failed.',
    );
    await _select(bloc);
    bloc.add(
      const PlantHealthCheckAnalysisRequested(
        plantId: 'plant-1',
        plant: _tomato,
      ),
    );
    final failure = await bloc.stream.firstWhere(
      (state) =>
          state.status == PlantHealthCheckStatus.failure &&
          state.saveRetryAvailable,
    );
    expect(failure.diagnosis, sampleDiagnosis);
    diagnosisRepository.saveError = null;
    bloc.add(const PlantHealthCheckDiagnosisSaveRetryRequested());
    await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthCheckStatus.complete,
    );
    expect(diagnosisService.calls, 1);
    expect(diagnosisRepository.saveCalls, 2);
  });

  test('observation save retry does not submit image to AI again', () async {
    observationRepository.saveError = Exception('offline');
    await _select(bloc);
    bloc.add(
      const PlantHealthCheckAnalysisRequested(
        plantId: 'plant-1',
        plant: _tomato,
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state.observationSaveRetryAvailable,
    );
    expect(localImages.saveCalls, 0);
    observationRepository.saveError = null;
    bloc.add(const PlantHealthCheckObservationSaveRetryRequested());
    await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthCheckStatus.complete,
    );
    expect(observationService.calls, 1);
    expect(observationRepository.saveCalls, 2);
    expect(localImages.saveCalls, 1);
  });

  test('local write failure preserves saved findings and assessment', () async {
    localImages.saveError = Exception('disk full');
    await _select(bloc);
    bloc.add(
      const PlantHealthCheckAnalysisRequested(
        plantId: 'plant-1',
        plant: _tomato,
      ),
    );
    final result = await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthCheckStatus.complete,
    );
    expect(result.observationId, 'observation-1');
    expect(result.localImageWarning, contains('could not be saved'));
    expect(observationRepository.saveCalls, 1);
    expect(diagnosisRepository.saveCalls, 1);
  });

  test('note validation blocks analysis before any AI request', () async {
    await _select(bloc);
    bloc.add(PlantHealthCheckNoteChanged(List.filled(201, 'x').join()));
    bloc.add(
      const PlantHealthCheckAnalysisRequested(
        plantId: 'plant-1',
        plant: _tomato,
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state.status == PlantHealthCheckStatus.failure,
    );
    expect(observationService.calls, 0);
  });

  testWidgets('shows automatic-storage disclosure without a checkbox', (
    tester,
  ) async {
    final plants = FakePlantRepository();
    final details = PlantDetailsBloc(plants)
      ..add(const PlantDetailsWatchRequested('plant-1'));
    addTearDown(details.close);
    addTearDown(plants.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: details),
            BlocProvider.value(value: bloc),
          ],
          child: const Scaffold(body: PlantHealthCheckPage(plantId: 'plant-1')),
        ),
      ),
    );
    await tester.pump();
    plants.emitPlant('plant-1', _tomato);
    await tester.pump();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('sent to Firebase AI'), findsOneWidget);
    expect(observationService.calls, 0);
    expect(find.byKey(const ValueKey('analyze-plant-health')), findsOneWidget);
  });
}

Future<void> _select(PlantHealthCheckBloc bloc) async {
  bloc.add(const PlantHealthCheckImageRequested(PlantImageSource.gallery));
  await bloc.stream.firstWhere(
    (state) => state.status == PlantHealthCheckStatus.imageSelected,
  );
}

const _tomato = Plant(
  id: 'plant-1',
  commonName: 'Tomato',
  scientificName: 'Solanum lycopersicum',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.mature,
);

final _noPlantVisible = PlantObservation(
  schemaVersion: sampleObservation.schemaVersion,
  plantVisible: false,
  imageQuality: sampleObservation.imageQuality,
  possibleIdentification: sampleObservation.possibleIdentification,
  affectedParts: sampleObservation.affectedParts,
  observations: sampleObservation.observations,
  distribution: sampleObservation.distribution,
  severity: sampleObservation.severity,
  followUp: sampleObservation.followUp,
);

final _unusablePhoto = PlantObservation(
  schemaVersion: sampleObservation.schemaVersion,
  plantVisible: true,
  imageQuality: const ImageQuality(
    usable: false,
    issues: [ObservationIssue.blurred],
  ),
  possibleIdentification: sampleObservation.possibleIdentification,
  affectedParts: sampleObservation.affectedParts,
  observations: sampleObservation.observations,
  distribution: sampleObservation.distribution,
  severity: sampleObservation.severity,
  followUp: sampleObservation.followUp,
);
