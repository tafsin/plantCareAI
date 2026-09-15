import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_shared/errors.dart';

sealed class PlantIdentificationEvent extends Equatable {
  const PlantIdentificationEvent();
  @override
  List<Object?> get props => [];
}

final class IdentificationPhotoRequested extends PlantIdentificationEvent {
  const IdentificationPhotoRequested(this.source);
  final PlantImageSource source;
  @override
  List<Object?> get props => [source];
}

final class IdentificationSubmitted extends PlantIdentificationEvent {
  const IdentificationSubmitted();
}

final class IdentificationConsentChanged extends PlantIdentificationEvent {
  const IdentificationConsentChanged(this.consented);

  final bool consented;

  @override
  List<Object?> get props => [consented];
}

final class IdentificationReset extends PlantIdentificationEvent {
  const IdentificationReset();
}

final class IdentificationCandidateConfirmed extends PlantIdentificationEvent {
  const IdentificationCandidateConfirmed(this.candidate);
  final PlantIdentificationCandidate candidate;
  @override
  List<Object?> get props => [candidate];
}

final class OnboardingReviewRequested extends PlantIdentificationEvent {
  const OnboardingReviewRequested(this.draft);
  final PlantDraft draft;
  @override
  List<Object?> get props => [draft];
}

final class OnboardingEditRequested extends PlantIdentificationEvent {
  const OnboardingEditRequested();
}

final class OnboardingSaveRequested extends PlantIdentificationEvent {
  const OnboardingSaveRequested();
}

enum PlantOnboardingStep {
  method,
  picking,
  preview,
  identifying,
  candidates,
  profile,
  review,
  saving,
  saved,
}

final class PlantIdentificationState extends Equatable {
  const PlantIdentificationState({
    this.step = PlantOnboardingStep.method,
    this.result,
    this.draft,
    this.message,
    this.plantId,
    this.plantLimitReached = false,
    this.aiProcessingConsented = false,
  });
  final PlantOnboardingStep step;
  final PlantIdentificationResult? result;
  final PlantDraft? draft;
  final String? message;
  final String? plantId;
  final bool plantLimitReached;
  final bool aiProcessingConsented;
  @override
  List<Object?> get props => [
    step,
    result,
    draft,
    message,
    plantId,
    plantLimitReached,
    aiProcessingConsented,
  ];
}

/// One route-scoped workflow owns identification, confirmation, review and save.
/// Image bytes stay outside emitted states and are released on every exit path.
final class PlantIdentificationBloc
    extends Bloc<PlantIdentificationEvent, PlantIdentificationState> {
  PlantIdentificationBloc(
    this._picker,
    this._processor,
    this._service,
    this._repository,
    this._localImageRepository, {
    PremiumAccessSnapshot Function()? premiumAccess,
  }) : _premiumAccess =
           premiumAccess ?? (() => const PremiumAccessSnapshot.signedOut()),
       super(const PlantIdentificationState()) {
    on<IdentificationPhotoRequested>(_pick);
    on<IdentificationConsentChanged>((event, emit) {
      if (state.step != PlantOnboardingStep.preview) return;
      emit(
        PlantIdentificationState(
          step: state.step,
          message: state.message,
          aiProcessingConsented: event.consented,
        ),
      );
    });
    on<IdentificationSubmitted>(_identify);
    on<IdentificationReset>((event, emit) {
      if (state.step == PlantOnboardingStep.saving) return;
      _epoch++;
      _releaseImage();
      emit(const PlantIdentificationState());
    });
    on<IdentificationCandidateConfirmed>((event, emit) {
      final result = state.result;
      if (state.step != PlantOnboardingStep.candidates ||
          result == null ||
          result.confidence == IdentificationConfidence.low ||
          !result.candidates.contains(event.candidate)) {
        return;
      }
      final candidate = event.candidate;
      emit(
        PlantIdentificationState(
          step: PlantOnboardingStep.profile,
          draft: PlantDraft(
            commonName: candidate.commonName,
            scientificName: candidate.scientificName,
            environment: PlantEnvironment.indoor,
            growingMedium: GrowingMedium.pot,
            sunlight: Sunlight.partial,
            growthStage: GrowthStage.vegetative,
          ),
        ),
      );
    });
    on<OnboardingReviewRequested>((event, emit) {
      if (state.step != PlantOnboardingStep.profile) return;
      final draft = event.draft.normalized();
      final error =
          PlantValidator.draft(draft) ??
          (draft.potSizeLiters != null && !draft.potSizeLiters!.isFinite
              ? 'Enter a valid pot size.'
              : null) ??
          (OnboardingPlantSupport.hasNameConflict(
                draft.commonName,
                draft.scientificName,
              )
              ? 'These names refer to different supported plants. Please correct the names.'
              : null);
      emit(
        PlantIdentificationState(
          step: error == null
              ? PlantOnboardingStep.review
              : PlantOnboardingStep.profile,
          draft: draft,
          message: error,
        ),
      );
    });
    on<OnboardingEditRequested>((event, emit) {
      if (state.step != PlantOnboardingStep.review) return;
      emit(
        PlantIdentificationState(
          step: PlantOnboardingStep.profile,
          draft: state.draft,
        ),
      );
    });
    on<OnboardingSaveRequested>(_save);
  }

  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;
  final PlantIdentificationService _service;
  final PlantRepository _repository;
  final LocalPlantImageRepository _localImageRepository;
  final PremiumAccessSnapshot Function() _premiumAccess;
  SelectedPlantImage? _image;
  var _epoch = 0;
  var _pickInProgress = false;
  bool get supportsCamera => _picker.supportsCamera;
  Uint8List? get selectedImageBytes => _image?.bytes;

  bool _active(int epoch) => !isClosed && epoch == _epoch;
  void _releaseImage() {
    // Best-effort zeroing of our owned buffers; SDK/platform copies are outside
    // application ownership. No image or filename enters BLoC states/storage.
    _image?.bytes.fillRange(0, _image!.bytes.length, 0);
    _image = null;
  }

  Future<void> _pick(
    IdentificationPhotoRequested event,
    Emitter<PlantIdentificationState> emit,
  ) async {
    if (_pickInProgress ||
        !{
          PlantOnboardingStep.method,
          PlantOnboardingStep.candidates,
          PlantOnboardingStep.preview,
        }.contains(state.step)) {
      return;
    }
    _pickInProgress = true;
    try {
      final capability = await _creationCapability();
      if (!capability.allowed) {
        emit(
          PlantIdentificationState(
            message: capability.message,
            plantLimitReached: true,
          ),
        );
        return;
      }
    } on AppError catch (error) {
      emit(PlantIdentificationState(message: error.message));
      return;
    } catch (_) {
      emit(
        const PlantIdentificationState(
          message: 'Could not check your plant allowance. Please try again.',
        ),
      );
      return;
    } finally {
      _pickInProgress = false;
    }
    final epoch = ++_epoch;
    _releaseImage();
    emit(const PlantIdentificationState(step: PlantOnboardingStep.picking));
    PickedPlantImage? picked;
    SelectedPlantImage? processed;
    try {
      picked = await _picker.pick(event.source);
      if (!_active(epoch)) return;
      if (picked == null) {
        emit(
          const PlantIdentificationState(message: 'Photo selection cancelled.'),
        );
        return;
      }
      processed = await _processor.process(picked);
      if (!_active(epoch)) return;
      _image = processed;
      processed = null;
      emit(const PlantIdentificationState(step: PlantOnboardingStep.preview));
    } on AppError catch (error) {
      if (_active(epoch)) {
        emit(PlantIdentificationState(message: error.message));
      }
    } catch (_) {
      if (_active(epoch)) {
        emit(
          const PlantIdentificationState(
            message: 'Could not open this photo. Try a JPEG or PNG image.',
          ),
        );
      }
    } finally {
      if (picked != null && !identical(picked.bytes, _image?.bytes)) {
        picked.bytes.fillRange(0, picked.bytes.length, 0);
      }
      processed?.bytes.fillRange(0, processed.bytes.length, 0);
    }
  }

  Future<void> _identify(
    IdentificationSubmitted event,
    Emitter<PlantIdentificationState> emit,
  ) async {
    if (state.step != PlantOnboardingStep.preview ||
        _image == null ||
        !state.aiProcessingConsented) {
      return;
    }
    final epoch = _epoch;
    final image = _image!;
    emit(const PlantIdentificationState(step: PlantOnboardingStep.identifying));
    try {
      final result = await _service.identify(image: image);
      if (_active(epoch)) {
        emit(
          PlantIdentificationState(
            step: PlantOnboardingStep.candidates,
            result: result,
          ),
        );
      }
    } on AppError catch (error) {
      if (_active(epoch)) {
        emit(
          PlantIdentificationState(
            step: PlantOnboardingStep.preview,
            message: error.message,
          ),
        );
      }
    } catch (_) {
      if (_active(epoch)) {
        emit(
          const PlantIdentificationState(
            step: PlantOnboardingStep.preview,
            message:
                'Could not identify this plant. Try again or add manually.',
          ),
        );
      }
    }
  }

  Future<void> _save(
    OnboardingSaveRequested event,
    Emitter<PlantIdentificationState> emit,
  ) async {
    if (state.step != PlantOnboardingStep.review || state.draft == null) return;
    final draft = state.draft!;
    emit(
      PlantIdentificationState(step: PlantOnboardingStep.saving, draft: draft),
    );
    try {
      final capability = await _creationCapability();
      if (!capability.allowed) {
        emit(
          PlantIdentificationState(
            step: PlantOnboardingStep.review,
            draft: draft,
            message: capability.message,
            plantLimitReached: true,
          ),
        );
        return;
      }
      final id = await _repository.addPlant(draft);
      String? localImageWarning;
      final image = _image;
      if (image != null) {
        try {
          await _localImageRepository.save(
            purpose: LocalPlantImagePurpose.plantIdentification,
            plantId: id,
            bytes: image.bytes,
            createdAt: DateTime.now().toUtc(),
          );
        } catch (_) {
          localImageWarning =
              'Plant saved, but its photo could not be saved on this device.';
        }
      }
      _releaseImage();
      if (!isClosed) {
        emit(
          PlantIdentificationState(
            step: PlantOnboardingStep.saved,
            plantId: id,
            message: localImageWarning,
          ),
        );
      }
    } on AppError catch (error) {
      if (!isClosed) {
        emit(
          PlantIdentificationState(
            step: PlantOnboardingStep.review,
            draft: draft,
            message: error.message,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          PlantIdentificationState(
            step: PlantOnboardingStep.review,
            draft: draft,
            message: 'Could not save your plant. Your details are still here. Please retry.',
          ),
        );
      }
    }
  }

  Future<PlantCreationCapability> _creationCapability() async =>
      PlantCapabilityPolicy.createSavedPlant(
        savedPlantCount: await _repository.countPlants(),
        premiumAccess: _premiumAccess(),
      );

  @override
  Future<void> close() {
    _epoch++;
    _releaseImage();
    return super.close();
  }
}
