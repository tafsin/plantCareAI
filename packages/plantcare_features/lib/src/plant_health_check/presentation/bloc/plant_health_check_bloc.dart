import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_shared/errors.dart';

sealed class PlantHealthCheckEvent extends Equatable {
  const PlantHealthCheckEvent();

  @override
  List<Object?> get props => [];
}

final class PlantHealthCheckImageRequested extends PlantHealthCheckEvent {
  const PlantHealthCheckImageRequested(this.source);

  final PlantImageSource source;

  @override
  List<Object?> get props => [source];
}

final class PlantHealthCheckImageRemoved extends PlantHealthCheckEvent {
  const PlantHealthCheckImageRemoved();
}

final class PlantHealthCheckNoteChanged extends PlantHealthCheckEvent {
  const PlantHealthCheckNoteChanged(this.note);

  final String note;

  @override
  List<Object?> get props => [note];
}

final class PlantHealthCheckAnalysisRequested extends PlantHealthCheckEvent {
  const PlantHealthCheckAnalysisRequested({
    required this.plantId,
    required this.plant,
  });

  final String plantId;
  final Plant plant;

  @override
  List<Object?> get props => [plantId, plant];
}

final class PlantHealthCheckObservationSaveRetryRequested
    extends PlantHealthCheckEvent {
  const PlantHealthCheckObservationSaveRetryRequested();
}

final class PlantHealthCheckAssessmentRetryRequested
    extends PlantHealthCheckEvent {
  const PlantHealthCheckAssessmentRetryRequested({
    required this.plantId,
    required this.plant,
    required this.observationId,
    required this.observation,
  });

  final String plantId;
  final Plant plant;
  final String observationId;
  final PlantObservation observation;

  @override
  List<Object?> get props => [plantId, plant, observationId, observation];
}

final class PlantHealthCheckDiagnosisSaveRetryRequested
    extends PlantHealthCheckEvent {
  const PlantHealthCheckDiagnosisSaveRetryRequested();
}

enum PlantHealthCheckStatus {
  initial,
  processingImage,
  imageSelected,
  checkingPhoto,
  observing,
  savingObservation,
  resolvingPlant,
  retrievingEvidence,
  insufficientEvidence,
  generatingDiagnosis,
  savingDiagnosis,
  complete,
  photoRejected,
  failure,
}

enum PlantHealthCheckStage {
  checkingPhoto,
  lookingForVisibleSigns,
  reviewingTrustedInformation,
  preparingAssessment,
  savingResults,
}

final class PlantHealthCheckState extends Equatable {
  const PlantHealthCheckState({
    this.status = PlantHealthCheckStatus.initial,
    this.hasImage = false,
    this.note = '',
    this.observation,
    this.observationId,
    this.retrieval,
    this.diagnosis,
    this.diagnosisId,
    this.errorMessage,
    this.saveRetryAvailable = false,
    this.observationSaveRetryAvailable = false,
    this.localImageWarning,
    this.activeStage,
    this.completedStages = const {},
  });

  static const maxNoteLength = 200;

  final PlantHealthCheckStatus status;
  final bool hasImage;
  final String note;
  final PlantObservation? observation;
  final String? observationId;
  final KnowledgeRetrievalResult? retrieval;
  final PlantDiagnosis? diagnosis;
  final String? diagnosisId;
  final String? errorMessage;
  final bool saveRetryAvailable;
  final bool observationSaveRetryAvailable;
  final String? localImageWarning;
  final PlantHealthCheckStage? activeStage;
  final Set<PlantHealthCheckStage> completedStages;

  bool get busy => switch (status) {
    PlantHealthCheckStatus.processingImage ||
    PlantHealthCheckStatus.checkingPhoto ||
    PlantHealthCheckStatus.observing ||
    PlantHealthCheckStatus.savingObservation ||
    PlantHealthCheckStatus.resolvingPlant ||
    PlantHealthCheckStatus.retrievingEvidence ||
    PlantHealthCheckStatus.generatingDiagnosis ||
    PlantHealthCheckStatus.savingDiagnosis => true,
    _ => false,
  };

  bool get noteValid => note.trim().length <= maxNoteLength;

  bool get canAnalyze => hasImage && noteValid && !busy && diagnosis == null;

  bool get hasSavedObservation => observation != null && observationId != null;

  PlantHealthCheckState copyWith({
    PlantHealthCheckStatus? status,
    bool? hasImage,
    String? note,
    PlantObservation? observation,
    String? observationId,
    KnowledgeRetrievalResult? retrieval,
    PlantDiagnosis? diagnosis,
    String? diagnosisId,
    String? errorMessage,
    bool clearError = false,
    bool? saveRetryAvailable,
    bool? observationSaveRetryAvailable,
    String? localImageWarning,
    bool clearLocalImageWarning = false,
    PlantHealthCheckStage? activeStage,
    Set<PlantHealthCheckStage>? completedStages,
  }) {
    return PlantHealthCheckState(
      status: status ?? this.status,
      hasImage: hasImage ?? this.hasImage,
      note: note ?? this.note,
      observation: observation ?? this.observation,
      observationId: observationId ?? this.observationId,
      retrieval: retrieval ?? this.retrieval,
      diagnosis: diagnosis ?? this.diagnosis,
      diagnosisId: diagnosisId ?? this.diagnosisId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      saveRetryAvailable: saveRetryAvailable ?? this.saveRetryAvailable,
      observationSaveRetryAvailable:
          observationSaveRetryAvailable ?? this.observationSaveRetryAvailable,
      localImageWarning: clearLocalImageWarning
          ? null
          : localImageWarning ?? this.localImageWarning,
      activeStage: activeStage,
      completedStages: completedStages ?? this.completedStages,
    );
  }

  @override
  List<Object?> get props => [
    status,
    hasImage,
    note,
    observation,
    observationId,
    retrieval,
    diagnosis,
    diagnosisId,
    errorMessage,
    saveRetryAvailable,
    observationSaveRetryAvailable,
    localImageWarning,
    activeStage,
    completedStages,
  ];
}

final class PlantHealthCheckBloc
    extends Bloc<PlantHealthCheckEvent, PlantHealthCheckState> {
  PlantHealthCheckBloc(
    this._picker,
    this._processor,
    this._observationService,
    this._observationRepository,
    this._knowledgeRepository,
    this._diagnosisRepository,
    this._diagnosisService,
    this._resolver,
    this._ranker,
    this._localImageRepository,
  ) : super(const PlantHealthCheckState()) {
    on<PlantHealthCheckImageRequested>(_onImageRequested);
    on<PlantHealthCheckImageRemoved>(_onImageRemoved);
    on<PlantHealthCheckNoteChanged>(_onNoteChanged);
    on<PlantHealthCheckAnalysisRequested>(_onAnalysisRequested);
    on<PlantHealthCheckObservationSaveRetryRequested>(
      _onObservationSaveRetryRequested,
    );
    on<PlantHealthCheckAssessmentRetryRequested>(_onAssessmentRetryRequested);
    on<PlantHealthCheckDiagnosisSaveRetryRequested>(_onDiagnosisSaveRetry);
  }

  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;
  final PlantObservationService _observationService;
  final PlantObservationRepository _observationRepository;
  final KnowledgeRepository _knowledgeRepository;
  final PlantDiagnosisRepository _diagnosisRepository;
  final PlantDiagnosisService _diagnosisService;
  final PlantNameResolver _resolver;
  final KnowledgeRanker _ranker;
  final LocalPlantImageRepository _localImageRepository;
  PlantHealthCheckAssessmentRetryRequested? _lastAssessmentRequest;
  PlantHealthCheckAnalysisRequested? _pendingObservationRequest;
  PlantObservation? _pendingObservation;
  SelectedPlantImage? _image;
  bool _inFlight = false;

  bool get supportsCamera => _picker.supportsCamera;
  Uint8List? get selectedImageBytes => _image?.bytes;

  void _releaseImage() {
    _image?.bytes.fillRange(0, _image!.bytes.length, 0);
    _image = null;
  }

  Future<void> _onImageRequested(
    PlantHealthCheckImageRequested event,
    Emitter<PlantHealthCheckState> emit,
  ) async {
    if (state.busy) return;
    PickedPlantImage? picked;
    try {
      picked = await _picker.pick(event.source);
      if (picked == null) return;
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.processingImage,
          clearError: true,
        ),
      );
      final image = await _processor.process(picked);
      _releaseImage();
      _image = image;
      emit(
        PlantHealthCheckState(
          status: PlantHealthCheckStatus.imageSelected,
          hasImage: true,
          note: state.note,
        ),
      );
    } on AppError catch (error) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.failure,
          errorMessage: 'Couldn\'t select that image. Try another photo.',
        ),
      );
    } finally {
      if (picked != null && !identical(picked.bytes, _image?.bytes)) {
        picked.bytes.fillRange(0, picked.bytes.length, 0);
      }
    }
  }

  void _onImageRemoved(
    PlantHealthCheckImageRemoved event,
    Emitter<PlantHealthCheckState> emit,
  ) {
    if (!state.busy) {
      _releaseImage();
      emit(const PlantHealthCheckState());
    }
  }

  void _onNoteChanged(
    PlantHealthCheckNoteChanged event,
    Emitter<PlantHealthCheckState> emit,
  ) {
    if (state.busy) return;
    emit(
      state.copyWith(
        status: !state.hasImage
            ? PlantHealthCheckStatus.initial
            : PlantHealthCheckStatus.imageSelected,
        note: event.note,
        clearError: true,
      ),
    );
  }

  Future<void> _onAnalysisRequested(
    PlantHealthCheckAnalysisRequested event,
    Emitter<PlantHealthCheckState> emit,
  ) async {
    if (_inFlight || state.busy) return;
    final image = _image;
    if (image == null) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.failure,
          errorMessage: 'Choose a symptom photo first.',
        ),
      );
      return;
    }
    if (!state.noteValid) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.failure,
          errorMessage: 'Keep the note under 200 characters.',
        ),
      );
      return;
    }
    _inFlight = true;
    try {
      emit(_stage(PlantHealthCheckStage.checkingPhoto));
      emit(_stage(PlantHealthCheckStage.lookingForVisibleSigns));
      final observation = await _observationService.observe(
        image: image,
        context: PlantObservationContext(
          commonName: event.plant.commonName,
          scientificName: event.plant.scientificName,
          environment: event.plant.environment.name,
          growthStage: event.plant.growthStage.name,
        ),
      );
      if (!observation.plantVisible) {
        _releaseImage();
        emit(
          PlantHealthCheckState(
            status: PlantHealthCheckStatus.photoRejected,
            note: state.note,
            observation: observation,
            errorMessage: 'No plant was clearly visible. Take another close photo of the affected area.',
          ),
        );
        return;
      }
      if (!observation.imageQuality.usable) {
        _releaseImage();
        emit(
          PlantHealthCheckState(
            status: PlantHealthCheckStatus.photoRejected,
            note: state.note,
            observation: observation,
            errorMessage: 'That photo is not clear enough for a health assessment. Try sharper focus and better light.',
          ),
        );
        return;
      }
      _pendingObservationRequest = event;
      _pendingObservation = observation;
      await _saveObservationAndContinue(event, observation, emit);
    } on AppError catch (error) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.failure,
          errorMessage: 'The plant health check could not be completed.',
        ),
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _onObservationSaveRetryRequested(
    PlantHealthCheckObservationSaveRetryRequested event,
    Emitter<PlantHealthCheckState> emit,
  ) async {
    if (_inFlight || state.busy || !state.observationSaveRetryAvailable) return;
    final request = _pendingObservationRequest;
    final observation = _pendingObservation;
    if (request == null || observation == null || _image == null) return;
    _inFlight = true;
    try {
      await _saveObservationAndContinue(request, observation, emit);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _saveObservationAndContinue(
    PlantHealthCheckAnalysisRequested request,
    PlantObservation observation,
    Emitter<PlantHealthCheckState> emit,
  ) async {
    emit(_stage(PlantHealthCheckStage.savingResults));
    String observationId;
    try {
      observationId = await _observationRepository.saveObservation(
        request.plantId,
        observation,
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.failure,
          observation: observation,
          observationSaveRetryAvailable: true,
          errorMessage: 'Photo findings were prepared but could not be saved. Retry saves these findings without analyzing the image again.',
        ),
      );
      return;
    }
    final savedObservation = observation.copyWith(
      id: observationId,
      modelName: _observationService.modelName,
    );
    String? localImageWarning;
    final image = _image;
    if (image != null) {
      try {
        await _localImageRepository.save(
          purpose: LocalPlantImagePurpose.healthCheck,
          plantId: request.plantId,
          observationId: observationId,
          bytes: image.bytes,
          createdAt: DateTime.now().toUtc(),
        );
      } catch (_) {
        localImageWarning = 'Photo findings were saved, but the image could not be saved on this device.';
      }
    }
    _releaseImage();
    _pendingObservationRequest = null;
    _pendingObservation = null;
    emit(
      state.copyWith(
        hasImage: false,
        observation: savedObservation,
        observationId: observationId,
        observationSaveRetryAvailable: false,
        localImageWarning: localImageWarning,
        clearError: true,
      ),
    );
    await _runAssessment(
      plantId: request.plantId,
      plant: request.plant,
      observationId: observationId,
      observation: savedObservation,
      emit: emit,
    );
  }

  Future<void> _onAssessmentRetryRequested(
    PlantHealthCheckAssessmentRetryRequested event,
    Emitter<PlantHealthCheckState> emit,
  ) async {
    if (_inFlight || state.busy) return;
    _inFlight = true;
    try {
      await _runAssessment(
        plantId: event.plantId,
        plant: event.plant,
        observationId: event.observationId,
        observation: event.observation,
        emit: emit,
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _runAssessment({
    required String plantId,
    required Plant plant,
    required String observationId,
    required PlantObservation observation,
    required Emitter<PlantHealthCheckState> emit,
  }) async {
    _lastAssessmentRequest = PlantHealthCheckAssessmentRetryRequested(
      plantId: plantId,
      plant: plant,
      observationId: observationId,
      observation: observation,
    );
    emit(
      PlantHealthCheckState(
        status: PlantHealthCheckStatus.resolvingPlant,
        note: state.note,
        observation: observation,
        observationId: observationId,
        localImageWarning: state.localImageWarning,
        activeStage: PlantHealthCheckStage.reviewingTrustedInformation,
        completedStages: const {
          PlantHealthCheckStage.checkingPhoto,
          PlantHealthCheckStage.lookingForVisibleSigns,
        },
      ),
    );
    final resolution = _resolver.resolve(plant, observation);
    final canonicalKey = switch (resolution.status) {
      PlantResolutionStatus.resolved => resolution.canonicalKey!,
      PlantResolutionStatus.unsupported => throw const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.unsupportedPlant,
        'This plant is not supported by the current knowledge library.',
      ),
      PlantResolutionStatus.conflict => throw const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.plantConflict,
        'The saved profile and photo do not clearly match. Review the plant profile before continuing.',
      ),
    };
    emit(
      state.copyWith(
        status: PlantHealthCheckStatus.retrievingEvidence,
        observation: observation,
        observationId: observationId,
        activeStage: PlantHealthCheckStage.reviewingTrustedInformation,
        completedStages: const {
          PlantHealthCheckStage.checkingPhoto,
          PlantHealthCheckStage.lookingForVisibleSigns,
        },
        clearError: true,
      ),
    );
    final evidence = await _knowledgeRepository.loadPreferredEvidenceForPlant(
      canonicalKey,
    );
    final ranked = _ranker.rank(
      canonicalPlantKey: canonicalKey,
      plant: plant,
      observation: observation,
      chunks: evidence.chunks,
    );
    if (ranked.isEmpty) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.insufficientEvidence,
          observation: observation,
          observationId: observationId,
          retrieval: KnowledgeRetrievalResult(
            canonicalPlantKey: canonicalKey,
            datasetVersion: evidence.datasetVersion,
            algorithmVersion: KnowledgeVersions.algorithm,
            rankedMatches: const [],
            warnings: evidence.warnings,
          ),
          errorMessage: 'Photo findings were saved, but there was not enough trusted information to complete an assessment.',
          completedStages: const {
            PlantHealthCheckStage.checkingPhoto,
            PlantHealthCheckStage.lookingForVisibleSigns,
          },
        ),
      );
      return;
    }
    final requestedSourceIds = ranked
        .expand((match) => match.chunk.sourceIds)
        .toSet();
    final sourceById = {
      for (final source in evidence.sources) source.id: source,
    };
    if (evidence.warnings.isNotEmpty ||
        !sourceById.keys.toSet().containsAll(requestedSourceIds)) {
      throw const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.malformedSources,
        'Photo findings were saved, but trusted source details were unavailable.',
      );
    }
    final retrieval = KnowledgeRetrievalResult(
      canonicalPlantKey: canonicalKey,
      datasetVersion: evidence.datasetVersion,
      algorithmVersion: KnowledgeVersions.algorithm,
      rankedMatches: ranked
          .map(
            (match) => match.withSources(
              match.chunk.sourceIds
                  .map((id) => sourceById[id]!)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      warnings: evidence.warnings,
    );
    emit(
      state.copyWith(
        status: PlantHealthCheckStatus.generatingDiagnosis,
        observation: observation,
        observationId: observationId,
        retrieval: retrieval,
        activeStage: PlantHealthCheckStage.preparingAssessment,
        completedStages: const {
          PlantHealthCheckStage.checkingPhoto,
          PlantHealthCheckStage.lookingForVisibleSigns,
          PlantHealthCheckStage.reviewingTrustedInformation,
        },
      ),
    );
    final diagnosis = await _diagnosisService.generate(
      DiagnosisRequest(
        plant: plant,
        observation: observation,
        retrieval: retrieval,
      ),
    );
    _validateDiagnosisEvidence(diagnosis, retrieval);
    await _saveDiagnosis(
      plantId: plantId,
      observationId: observationId,
      observation: observation,
      retrieval: retrieval,
      diagnosis: diagnosis,
      emit: emit,
    );
  }

  Future<void> _saveDiagnosis({
    required String plantId,
    required String observationId,
    required PlantObservation observation,
    required KnowledgeRetrievalResult retrieval,
    required PlantDiagnosis diagnosis,
    required Emitter<PlantHealthCheckState> emit,
  }) async {
    emit(
      state.copyWith(
        status: PlantHealthCheckStatus.savingDiagnosis,
        observation: observation,
        observationId: observationId,
        retrieval: retrieval,
        diagnosis: diagnosis,
        activeStage: PlantHealthCheckStage.savingResults,
        completedStages: const {
          PlantHealthCheckStage.checkingPhoto,
          PlantHealthCheckStage.lookingForVisibleSigns,
          PlantHealthCheckStage.reviewingTrustedInformation,
          PlantHealthCheckStage.preparingAssessment,
        },
      ),
    );
    try {
      final diagnosisId = await _diagnosisRepository.saveDiagnosis(
        plantId,
        observationId,
        diagnosis,
      );
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.complete,
          observation: observation,
          observationId: observationId,
          retrieval: retrieval,
          diagnosis: diagnosis.copyWith(id: diagnosisId),
          diagnosisId: diagnosisId,
          saveRetryAvailable: false,
          completedStages: const {
            PlantHealthCheckStage.checkingPhoto,
            PlantHealthCheckStage.lookingForVisibleSigns,
            PlantHealthCheckStage.reviewingTrustedInformation,
            PlantHealthCheckStage.preparingAssessment,
            PlantHealthCheckStage.savingResults,
          },
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PlantHealthCheckStatus.failure,
          observation: observation,
          observationId: observationId,
          retrieval: retrieval,
          diagnosis: diagnosis,
          errorMessage:
              'The health assessment was prepared but could not be saved.',
          saveRetryAvailable: true,
          completedStages: const {
            PlantHealthCheckStage.checkingPhoto,
            PlantHealthCheckStage.lookingForVisibleSigns,
            PlantHealthCheckStage.reviewingTrustedInformation,
            PlantHealthCheckStage.preparingAssessment,
          },
        ),
      );
    }
  }

  Future<void> _onDiagnosisSaveRetry(
    PlantHealthCheckDiagnosisSaveRetryRequested event,
    Emitter<PlantHealthCheckState> emit,
  ) async {
    if (_inFlight || state.busy || !state.saveRetryAvailable) return;
    final request = _lastAssessmentRequest;
    final retrieval = state.retrieval;
    final diagnosis = state.diagnosis;
    if (request == null || retrieval == null || diagnosis == null) return;
    _inFlight = true;
    try {
      await _saveDiagnosis(
        plantId: request.plantId,
        observationId: request.observationId,
        observation: request.observation,
        retrieval: retrieval,
        diagnosis: diagnosis,
        emit: emit,
      );
    } finally {
      _inFlight = false;
    }
  }

  PlantHealthCheckState _stage(PlantHealthCheckStage stage) {
    final completed = switch (stage) {
      PlantHealthCheckStage.checkingPhoto => const <PlantHealthCheckStage>{},
      PlantHealthCheckStage.lookingForVisibleSigns => const {
        PlantHealthCheckStage.checkingPhoto,
      },
      PlantHealthCheckStage.reviewingTrustedInformation => const {
        PlantHealthCheckStage.checkingPhoto,
        PlantHealthCheckStage.lookingForVisibleSigns,
      },
      PlantHealthCheckStage.preparingAssessment => const {
        PlantHealthCheckStage.checkingPhoto,
        PlantHealthCheckStage.lookingForVisibleSigns,
        PlantHealthCheckStage.reviewingTrustedInformation,
      },
      PlantHealthCheckStage.savingResults => const {
        PlantHealthCheckStage.checkingPhoto,
        PlantHealthCheckStage.lookingForVisibleSigns,
        PlantHealthCheckStage.reviewingTrustedInformation,
        PlantHealthCheckStage.preparingAssessment,
      },
    };
    final status = switch (stage) {
      PlantHealthCheckStage.checkingPhoto =>
        PlantHealthCheckStatus.checkingPhoto,
      PlantHealthCheckStage.lookingForVisibleSigns =>
        PlantHealthCheckStatus.observing,
      PlantHealthCheckStage.reviewingTrustedInformation =>
        PlantHealthCheckStatus.retrievingEvidence,
      PlantHealthCheckStage.preparingAssessment =>
        PlantHealthCheckStatus.generatingDiagnosis,
      PlantHealthCheckStage.savingResults =>
        PlantHealthCheckStatus.savingObservation,
    };
    return state.copyWith(
      status: status,
      activeStage: stage,
      completedStages: completed,
      clearError: true,
    );
  }

  @override
  Future<void> close() {
    _releaseImage();
    return super.close();
  }

  void _validateDiagnosisEvidence(
    PlantDiagnosis diagnosis,
    KnowledgeRetrievalResult retrieval,
  ) {
    final allowedChunkIds = retrieval.rankedMatches
        .map((match) => match.chunk.id)
        .toSet();
    final referencedChunkIds = <String>{
      ...diagnosis.evidenceChunkIds,
      ...diagnosis.possibleIssues.expand((issue) => issue.evidenceChunkIds),
      ...diagnosis.recommendedActions.expand(
        (action) => action.evidenceChunkIds,
      ),
      ...diagnosis.avoidActions.expand((action) => action.evidenceChunkIds),
    };
    if (!allowedChunkIds.containsAll(referencedChunkIds)) {
      throw const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.unknownEvidenceReference,
        'The health assessment could not be validated against trusted sources.',
      );
    }
  }
}
