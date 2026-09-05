import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/plant_identification.dart';

import '../../helpers/fake_plant_repository.dart';
import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));
void main() {
  late Picker picker;
  late Processor processor;
  late IdentificationService service;
  late FakePlantRepository repository;
  late PlantIdentificationBloc bloc;
  setUp(() {
    picker = Picker();
    processor = Processor();
    service = IdentificationService();
    repository = FakePlantRepository();
    bloc = PlantIdentificationBloc(picker, processor, service, repository);
  });
  tearDown(() async {
    await bloc.close();
    await repository.close();
  });
  Future<void> pick() async {
    bloc.add(const IdentificationPhotoRequested(PlantImageSource.gallery));
    await settle();
  }

  Future<void> identify() async {
    await pick();
    bloc.add(const IdentificationConsentGranted());
    await settle();
  }

  Future<void> review() async {
    await identify();
    bloc.add(IdentificationCandidateConfirmed(service.value.candidates.first));
    await settle();
    bloc.add(OnboardingReviewRequested(bloc.state.draft!));
    await settle();
  }

  test('consent required; picker cancellation sends nothing', () async {
    bloc.add(const IdentificationConsentGranted());
    await settle();
    expect(service.calls, 0);
    picker.image = null;
    await pick();
    expect(bloc.state.step, PlantOnboardingStep.method);
    expect(service.calls, 0);
  });
  test(
    'processed image waits for consent, cancellation wipes buffers',
    () async {
      await pick();
      expect(bloc.state.step, PlantOnboardingStep.consent);
      expect(service.calls, 0);
      expect(picker.image!.bytes, everyElement(0));
      bloc.add(const IdentificationReset());
      await settle();
      expect(processor.last!.bytes, everyElement(0));
      expect(service.calls, 0);
    },
  );
  test('duplicate requests do not duplicate picker or AI calls', () async {
    picker.pending = Completer();
    bloc.add(const IdentificationPhotoRequested(PlantImageSource.gallery));
    bloc.add(const IdentificationPhotoRequested(PlantImageSource.gallery));
    await settle();
    expect(picker.calls, 1);
    picker.pending!.complete(picker.image);
    await settle();
    service.pending = Completer();
    bloc.add(const IdentificationConsentGranted());
    bloc.add(const IdentificationConsentGranted());
    await settle();
    expect(service.calls, 1);
    service.pending!.complete(result());
    await settle();
    expect(processor.last!.bytes, everyElement(0));
  });
  for (final confidence in [0.2, 0.7, 0.9]) {
    test('confidence $confidence confirmation policy', () async {
      service.value = result(confidence);
      await identify();
      expect(
        bloc.state.result!.confidence,
        confidence < .6
            ? IdentificationConfidence.low
            : confidence < .85
            ? IdentificationConfidence.medium
            : IdentificationConfidence.high,
      );
      expect(bloc.state.draft, isNull);
      expect(repository.addCalls, 0);
      bloc.add(
        IdentificationCandidateConfirmed(service.value.candidates.first),
      );
      await settle();
      expect(
        bloc.state.step,
        confidence < .6
            ? PlantOnboardingStep.candidates
            : PlantOnboardingStep.profile,
      );
      if (confidence >= .6) {
        expect(bloc.state.result, isNull);
        expect(bloc.state.draft!.commonName, 'Pothos');
      }
    });
  }
  for (final status in [
    IdentificationImageStatus.noPlantVisible,
    IdentificationImageStatus.insufficientImageQuality,
  ]) {
    test('handles ${status.name}', () async {
      service.value = PlantIdentificationResult(
        imageStatus: status,
        candidates: [],
      );
      await identify();
      expect(bloc.state.result!.imageStatus, status);
      expect(bloc.state.draft, isNull);
    });
  }
  for (final type in PlantIdentificationFailureType.values) {
    test('safe AI failure ${type.name} releases image', () async {
      service.error = PlantIdentificationFailure(type, 'Try again');
      await identify();
      expect(bloc.state.message, 'Try again');
      expect(bloc.state.step, PlantOnboardingStep.method);
      expect(processor.last!.bytes, everyElement(0));
      expect(repository.addCalls, 0);
    });
  }
  test('cancellation during AI ignores late success', () async {
    service.pending = Completer();
    await pick();
    bloc.add(const IdentificationConsentGranted());
    await settle();
    bloc.add(const IdentificationReset());
    await settle();
    service.pending!.complete(result());
    await settle();
    expect(bloc.state.step, PlantOnboardingStep.method);
    expect(bloc.state.result, isNull);
    expect(processor.last!.bytes, everyElement(0));
  });
  test('cancellation during picker wipes late image', () async {
    picker.pending = Completer();
    bloc.add(const IdentificationPhotoRequested(PlantImageSource.gallery));
    await settle();
    bloc.add(const IdentificationReset());
    await settle();
    final bytes = Uint8List.fromList([4, 5]);
    picker.pending!.complete(
      PickedPlantImage(bytes: bytes, filename: 'late.png'),
    );
    await settle();
    expect(bytes, everyElement(0));
    expect(bloc.state.step, PlantOnboardingStep.method);
  });
  test('reject all and foreign candidate do not create draft', () async {
    await identify();
    bloc.add(IdentificationCandidateConfirmed(candidate(.8)));
    await settle();
    expect(bloc.state.draft, isNull);
    bloc.add(const IdentificationReset());
    await settle();
    expect(bloc.state.result, isNull);
    expect(repository.addCalls, 0);
  });
  test(
    'save failure retains draft; edit and retry never regenerate AI',
    () async {
      await review();
      final draft = bloc.state.draft;
      repository.addError = Exception('offline');
      bloc.add(const OnboardingSaveRequested());
      await settle();
      expect(bloc.state.step, PlantOnboardingStep.review);
      expect(bloc.state.draft, draft);
      bloc.add(const OnboardingEditRequested());
      await settle();
      expect(bloc.state.draft, draft);
      bloc.add(OnboardingReviewRequested(draft!));
      await settle();
      repository.addError = null;
      bloc.add(const OnboardingSaveRequested());
      bloc.add(const OnboardingSaveRequested());
      await settle();
      expect(bloc.state.step, PlantOnboardingStep.saved);
      expect(bloc.state.draft, isNull);
      expect(repository.addCalls, 2);
      expect(service.calls, 1);
    },
  );
  test('name conflicts stop review and no save before review', () async {
    bloc.add(const OnboardingSaveRequested());
    await settle();
    expect(repository.addCalls, 0);
    await identify();
    bloc.add(IdentificationCandidateConfirmed(candidate()));
    await settle();
    bloc.add(
      const OnboardingReviewRequested(
        PlantDraft(
          commonName: 'Tomato',
          scientificName: 'Epipremnum aureum',
          environment: PlantEnvironment.indoor,
          growingMedium: GrowingMedium.ground,
          sunlight: Sunlight.low,
          growthStage: GrowthStage.mature,
        ),
      ),
    );
    await settle();
    expect(bloc.state.step, PlantOnboardingStep.profile);
    expect(bloc.state.message, contains('different supported plants'));
  });
  test(
    'image-processing failure stays local and allows another selection',
    () async {
      processor.error = const PlantObservationFailure(
        PlantObservationFailureType.unsupportedFormat,
        'Choose JPEG or PNG.',
      );
      await pick();
      expect(bloc.state.message, 'Choose JPEG or PNG.');
      expect(service.calls, 0);
      expect(picker.image!.bytes, everyElement(0));
      processor.error = null;
      await pick();
      expect(bloc.state.step, PlantOnboardingStep.consent);
    },
  );
  test('factory creates isolated workflow instances', () async {
    final factory = PlantIdentificationBlocFactory(
      picker,
      processor,
      service,
      repository,
    );
    final first = factory.create();
    final second = factory.create();
    expect(identical(first, second), isFalse);
    first.add(const IdentificationPhotoRequested(PlantImageSource.gallery));
    await settle();
    expect(first.state.step, PlantOnboardingStep.consent);
    expect(second.state.step, PlantOnboardingStep.method);
    await first.close();
    await second.close();
  });
  test('closing workflow releases selected bytes', () async {
    await pick();
    await bloc.close();
    expect(processor.last!.bytes, everyElement(0));
  });
}
