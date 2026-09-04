import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/knowledge_ranker.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/entities/plant_diagnosis.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/errors/plant_diagnosis_failure.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/repositories/plant_diagnosis_repository.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/services/plant_diagnosis_service.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_shared/errors.dart';

sealed class PlantDiagnosisEvent extends Equatable {
  const PlantDiagnosisEvent();
  @override
  List<Object?> get props => [];
}

final class PlantDiagnosisRequested extends PlantDiagnosisEvent {
  const PlantDiagnosisRequested({
    required this.plantId,
    required this.observationId,
    required this.plant,
    required this.observation,
  });

  final String plantId;
  final String observationId;
  final Plant plant;
  final PlantObservation observation;
  @override
  List<Object?> get props => [plantId, observationId, plant, observation];
}

final class DiagnosisPlantCandidateSelected extends PlantDiagnosisEvent {
  const DiagnosisPlantCandidateSelected(this.canonicalPlantKey);
  final String canonicalPlantKey;
  @override
  List<Object?> get props => [canonicalPlantKey];
}

final class PlantDiagnosisRetryRequested extends PlantDiagnosisEvent {
  const PlantDiagnosisRetryRequested();
}

final class PlantDiagnosisSaveRetryRequested extends PlantDiagnosisEvent {
  const PlantDiagnosisSaveRetryRequested();
}

enum PlantDiagnosisStatus {
  initial,
  retrievingEvidence,
  conflictSelectionRequired,
  insufficientEvidence,
  generating,
  saving,
  success,
  failure,
}

final class PlantDiagnosisState extends Equatable {
  const PlantDiagnosisState({
    this.status = PlantDiagnosisStatus.initial,
    this.candidates = const [],
    this.retrieval,
    this.diagnosis,
    this.diagnosisId,
    this.errorMessage,
    this.saveRetryAvailable = false,
  });

  final PlantDiagnosisStatus status;
  final List<String> candidates;
  final KnowledgeRetrievalResult? retrieval;
  final PlantDiagnosis? diagnosis;
  final String? diagnosisId;
  final String? errorMessage;
  final bool saveRetryAvailable;

  @override
  List<Object?> get props => [
    status,
    candidates,
    retrieval,
    diagnosis,
    diagnosisId,
    errorMessage,
    saveRetryAvailable,
  ];
}

final class PlantDiagnosisBloc
    extends Bloc<PlantDiagnosisEvent, PlantDiagnosisState> {
  PlantDiagnosisBloc(
    this._knowledgeRepository,
    this._diagnosisRepository,
    this._service,
    this._resolver,
    this._ranker,
  ) : super(const PlantDiagnosisState()) {
    on<PlantDiagnosisRequested>(_onRequested);
    on<DiagnosisPlantCandidateSelected>(_onCandidateSelected);
    on<PlantDiagnosisRetryRequested>(_onRetry);
    on<PlantDiagnosisSaveRetryRequested>(_onSaveRetry);
  }

  final KnowledgeRepository _knowledgeRepository;
  final PlantDiagnosisRepository _diagnosisRepository;
  final PlantDiagnosisService _service;
  final PlantNameResolver _resolver;
  final KnowledgeRanker _ranker;
  PlantDiagnosisRequested? _lastRequest;
  String? _selectedKey;
  bool _inFlight = false;

  Future<void> _onRequested(
    PlantDiagnosisRequested event,
    Emitter<PlantDiagnosisState> emit,
  ) async {
    if (_inFlight) return;
    _lastRequest = event;
    _selectedKey = null;
    final resolution = _resolver.resolve(event.plant, event.observation);
    switch (resolution.status) {
      case PlantResolutionStatus.unsupported:
        emit(
          const PlantDiagnosisState(
            status: PlantDiagnosisStatus.failure,
            errorMessage:
                'This plant is not supported by the current knowledge library.',
          ),
        );
      case PlantResolutionStatus.conflict:
        emit(
          PlantDiagnosisState(
            status: PlantDiagnosisStatus.conflictSelectionRequired,
            candidates: resolution.candidates!,
          ),
        );
      case PlantResolutionStatus.resolved:
        await _run(resolution.canonicalKey!, event, emit);
    }
  }

  Future<void> _onCandidateSelected(
    DiagnosisPlantCandidateSelected event,
    Emitter<PlantDiagnosisState> emit,
  ) async {
    final request = _lastRequest;
    if (_inFlight ||
        request == null ||
        state.status != PlantDiagnosisStatus.conflictSelectionRequired ||
        !state.candidates.contains(event.canonicalPlantKey)) {
      return;
    }
    await _run(event.canonicalPlantKey, request, emit);
  }

  Future<void> _onRetry(
    PlantDiagnosisRetryRequested event,
    Emitter<PlantDiagnosisState> emit,
  ) async {
    final request = _lastRequest;
    if (_inFlight || request == null) return;
    final selected = _selectedKey;
    if (selected == null) {
      await _onRequested(request, emit);
    } else {
      await _run(selected, request, emit);
    }
  }

  Future<void> _run(
    String canonicalKey,
    PlantDiagnosisRequested request,
    Emitter<PlantDiagnosisState> emit,
  ) async {
    _inFlight = true;
    _selectedKey = canonicalKey;
    emit(
      const PlantDiagnosisState(
        status: PlantDiagnosisStatus.retrievingEvidence,
      ),
    );
    try {
      final chunks = await _knowledgeRepository.loadChunksForPlant(
        canonicalKey,
      );
      final ranked = _ranker.rank(
        canonicalPlantKey: canonicalKey,
        plant: request.plant,
        observation: request.observation,
        chunks: chunks.items,
      );
      if (ranked.isEmpty) {
        emit(
          PlantDiagnosisState(
            status: PlantDiagnosisStatus.insufficientEvidence,
            retrieval: KnowledgeRetrievalResult(
              canonicalPlantKey: canonicalKey,
              datasetVersion: KnowledgeVersions.dataset,
              algorithmVersion: KnowledgeVersions.algorithm,
              rankedMatches: const [],
              warnings: chunks.warnings,
            ),
          ),
        );
        return;
      }
      final requestedSourceIds = ranked
          .expand((match) => match.chunk.sourceIds)
          .toSet();
      final sources = await _knowledgeRepository.loadSources(
        requestedSourceIds,
      );
      final sourceById = {
        for (final source in sources.items) source.id: source,
      };
      if (sources.warnings.isNotEmpty ||
          !sourceById.keys.toSet().containsAll(requestedSourceIds)) {
        throw const PlantDiagnosisFailure(
          PlantDiagnosisFailureType.malformedSources,
          'One or more evidence sources are missing or malformed.',
        );
      }
      final result = KnowledgeRetrievalResult(
        canonicalPlantKey: canonicalKey,
        datasetVersion: KnowledgeVersions.dataset,
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
        warnings: chunks.warnings,
      );
      emit(
        PlantDiagnosisState(
          status: PlantDiagnosisStatus.generating,
          retrieval: result,
        ),
      );
      final diagnosis = await _service.generate(
        DiagnosisRequest(
          plant: request.plant,
          observation: request.observation,
          retrieval: result,
        ),
      );
      await _save(request, result, diagnosis, emit);
    } on AppError catch (error) {
      emit(
        PlantDiagnosisState(
          status: PlantDiagnosisStatus.failure,
          retrieval: state.retrieval,
          diagnosis: state.diagnosis,
          errorMessage: error.message,
          saveRetryAvailable:
              error is PlantDiagnosisFailure &&
              error.type == PlantDiagnosisFailureType.saveFailed &&
              state.diagnosis != null,
        ),
      );
    } catch (_) {
      emit(
        PlantDiagnosisState(
          status: PlantDiagnosisStatus.failure,
          retrieval: state.retrieval,
          diagnosis: state.diagnosis,
          errorMessage:
              'The grounded diagnosis could not be completed. Try again.',
        ),
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _save(
    PlantDiagnosisRequested request,
    KnowledgeRetrievalResult result,
    PlantDiagnosis diagnosis,
    Emitter<PlantDiagnosisState> emit,
  ) async {
    emit(
      PlantDiagnosisState(
        status: PlantDiagnosisStatus.saving,
        retrieval: result,
        diagnosis: diagnosis,
      ),
    );
    try {
      final id = await _diagnosisRepository.saveDiagnosis(
        request.plantId,
        request.observationId,
        diagnosis,
      );
      emit(
        PlantDiagnosisState(
          status: PlantDiagnosisStatus.success,
          retrieval: result,
          diagnosis: diagnosis.copyWith(id: id),
          diagnosisId: id,
        ),
      );
    } catch (_) {
      throw const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.saveFailed,
        'The diagnosis was generated but could not be saved.',
      );
    }
  }

  Future<void> _onSaveRetry(
    PlantDiagnosisSaveRetryRequested event,
    Emitter<PlantDiagnosisState> emit,
  ) async {
    final request = _lastRequest;
    final diagnosis = state.diagnosis;
    final retrieval = state.retrieval;
    if (_inFlight ||
        request == null ||
        diagnosis == null ||
        retrieval == null) {
      return;
    }
    _inFlight = true;
    try {
      await _save(request, retrieval, diagnosis, emit);
    } on AppError catch (error) {
      emit(
        PlantDiagnosisState(
          status: PlantDiagnosisStatus.failure,
          retrieval: retrieval,
          diagnosis: diagnosis,
          errorMessage: error.message,
          saveRetryAvailable: true,
        ),
      );
    } finally {
      _inFlight = false;
    }
  }
}
