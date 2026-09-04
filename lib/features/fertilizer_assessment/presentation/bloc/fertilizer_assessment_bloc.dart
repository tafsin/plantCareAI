import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/repositories/care_log_repository.dart';
import 'package:plantcare_ai/features/care_history/domain/services/latest_care_logs.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/entities/fertilizer_assessment.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/errors/fertilizer_assessment_failure.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/repositories/fertilizer_assessment_repository.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/services/fertilizer_evidence_validator.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/services/fertilizer_policy.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/plants/domain/repositories/plant_repository.dart';

sealed class FertilizerAssessmentEvent extends Equatable {
  const FertilizerAssessmentEvent();
  @override
  List<Object?> get props => [];
}

final class FertilizerAssessmentStarted extends FertilizerAssessmentEvent {
  const FertilizerAssessmentStarted(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

final class FertilizerGrowthActivitySelected extends FertilizerAssessmentEvent {
  const FertilizerGrowthActivitySelected(this.activity);
  final GrowthActivity activity;
  @override
  List<Object?> get props => [activity];
}

final class FertilizerAssessmentSubmitted extends FertilizerAssessmentEvent {
  const FertilizerAssessmentSubmitted({required this.assessmentTime});
  final DateTime assessmentTime;
  @override
  List<Object?> get props => [assessmentTime];
}

final class FertilizerAssessmentSaveRetried extends FertilizerAssessmentEvent {
  const FertilizerAssessmentSaveRetried();
}

enum FertilizerAssessmentStatus {
  initial,
  loading,
  ready,
  calculating,
  unsupportedPlant,
  resultReady,
  saving,
  saved,
  failure,
}

final class FertilizerAssessmentState extends Equatable {
  const FertilizerAssessmentState({
    this.status = FertilizerAssessmentStatus.initial,
    this.plant,
    this.lastFertilizingLog,
    this.growthActivity,
    this.guidance,
    this.sources = const [],
    this.savedId,
    this.errorMessage,
    this.saveRetryAvailable = false,
  });

  final FertilizerAssessmentStatus status;
  final Plant? plant;
  final FertilizingLog? lastFertilizingLog;
  final GrowthActivity? growthActivity;
  final FertilizerGuidance? guidance;
  final List<KnowledgeSource> sources;
  final String? savedId;
  final String? errorMessage;
  final bool saveRetryAvailable;

  @override
  List<Object?> get props => [
    status,
    plant,
    lastFertilizingLog,
    growthActivity,
    guidance,
    sources,
    savedId,
    errorMessage,
    saveRetryAvailable,
  ];
}

final class FertilizerAssessmentBloc
    extends Bloc<FertilizerAssessmentEvent, FertilizerAssessmentState> {
  FertilizerAssessmentBloc(
    this._plants,
    this._careLogs,
    this._assessments,
    this._validator,
    this._engine,
  ) : super(const FertilizerAssessmentState()) {
    on<FertilizerAssessmentStarted>(_started);
    on<FertilizerGrowthActivitySelected>(_activitySelected);
    on<FertilizerAssessmentSubmitted>(_submitted);
    on<FertilizerAssessmentSaveRetried>(_retrySave);
  }

  final PlantRepository _plants;
  final CareLogRepository _careLogs;
  final FertilizerAssessmentRepository _assessments;
  final FertilizerEvidenceValidator _validator;
  final DeterministicFertilizerEngine _engine;
  String? _plantId;
  FertilizerAssessment? _pendingAssessment;
  bool _inFlight = false;

  Future<void> _started(
    FertilizerAssessmentStarted event,
    Emitter<FertilizerAssessmentState> emit,
  ) async {
    _plantId = event.plantId;
    emit(
      const FertilizerAssessmentState(
        status: FertilizerAssessmentStatus.loading,
      ),
    );
    try {
      final values = await Future.wait<Object?>([
        _plants.watchPlant(event.plantId).first,
        _careLogs.watchForPlant(event.plantId).first,
      ]);
      final plant = values[0] as Plant?;
      if (plant == null) {
        emit(
          const FertilizerAssessmentState(
            status: FertilizerAssessmentStatus.failure,
            errorMessage: 'Plant not found.',
          ),
        );
        return;
      }
      final latest = latestCareLogs(values[1]! as List<CareLog>);
      emit(
        FertilizerAssessmentState(
          status: FertilizerAssessmentStatus.ready,
          plant: plant,
          lastFertilizingLog: latest.fertilizing,
        ),
      );
    } catch (error) {
      emit(
        FertilizerAssessmentState(
          status: FertilizerAssessmentStatus.failure,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t load the plant and fertilizer history.',
        ),
      );
    }
  }

  void _activitySelected(
    FertilizerGrowthActivitySelected event,
    Emitter<FertilizerAssessmentState> emit,
  ) {
    if (_inFlight || state.plant == null) return;
    _pendingAssessment = null;
    emit(
      FertilizerAssessmentState(
        status: FertilizerAssessmentStatus.ready,
        plant: state.plant,
        lastFertilizingLog: state.lastFertilizingLog,
        growthActivity: event.activity,
      ),
    );
  }

  Future<void> _submitted(
    FertilizerAssessmentSubmitted event,
    Emitter<FertilizerAssessmentState> emit,
  ) async {
    final plant = state.plant;
    final activity = state.growthActivity;
    if (_inFlight ||
        state.status != FertilizerAssessmentStatus.ready ||
        plant == null ||
        activity == null) {
      return;
    }
    _inFlight = true;
    emit(
      FertilizerAssessmentState(
        status: FertilizerAssessmentStatus.calculating,
        plant: plant,
        lastFertilizingLog: state.lastFertilizingLog,
        growthActivity: activity,
      ),
    );
    try {
      final canonicalKey =
          canonicalPlantKeyFor(plant.scientificName) ??
          canonicalPlantKeyFor(plant.commonName);
      final guidance = _engine.calculate(
        FertilizerAssessmentInput(
          canonicalPlantKey: canonicalKey,
          environment: plant.environment,
          growthStage: plant.growthStage,
          growthActivity: activity,
          assessmentTime: event.assessmentTime,
          lastFertilizedAt: state.lastFertilizingLog?.occurredAt,
        ),
      );
      if (guidance.outcome == FertilizerOutcome.unsupportedPlant) {
        emit(
          FertilizerAssessmentState(
            status: FertilizerAssessmentStatus.unsupportedPlant,
            plant: plant,
            lastFertilizingLog: state.lastFertilizingLog,
            growthActivity: activity,
            guidance: guidance,
          ),
        );
        return;
      }
      emit(
        FertilizerAssessmentState(
          status: FertilizerAssessmentStatus.resultReady,
          plant: plant,
          lastFertilizingLog: state.lastFertilizingLog,
          growthActivity: activity,
          guidance: guidance,
        ),
      );
      final evidence = await _validator.validate(
        guidance.canonicalPlantKey!,
        guidance.evidenceChunkIds,
      );
      final assessment = FertilizerAssessment(
        id: '',
        growthActivity: activity,
        growthStageSnapshot: plant.growthStage,
        environmentSnapshot: plant.environment,
        guidance: guidance,
        createdAt: event.assessmentTime,
      );
      _pendingAssessment = assessment;
      await _save(assessment, evidence.sources, plant, emit);
    } on AppError catch (error) {
      emit(
        FertilizerAssessmentState(
          status: FertilizerAssessmentStatus.failure,
          plant: plant,
          lastFertilizingLog: state.lastFertilizingLog,
          growthActivity: activity,
          guidance: state.guidance,
          sources: state.sources,
          errorMessage: error.message,
          saveRetryAvailable: _pendingAssessment != null,
        ),
      );
    } catch (_) {
      emit(
        FertilizerAssessmentState(
          status: FertilizerAssessmentStatus.failure,
          plant: plant,
          lastFertilizingLog: state.lastFertilizingLog,
          growthActivity: activity,
          guidance: state.guidance,
          errorMessage: 'Couldn\'t complete fertilizer guidance. Try again.',
        ),
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _save(
    FertilizerAssessment assessment,
    List<KnowledgeSource> sources,
    Plant plant,
    Emitter<FertilizerAssessmentState> emit,
  ) async {
    emit(
      FertilizerAssessmentState(
        status: FertilizerAssessmentStatus.saving,
        plant: plant,
        lastFertilizingLog: state.lastFertilizingLog,
        growthActivity: assessment.growthActivity,
        guidance: assessment.guidance,
        sources: sources,
      ),
    );
    try {
      final id = await _assessments.save(_plantId!, assessment);
      emit(
        FertilizerAssessmentState(
          status: FertilizerAssessmentStatus.saved,
          plant: plant,
          lastFertilizingLog: state.lastFertilizingLog,
          growthActivity: assessment.growthActivity,
          guidance: assessment.guidance,
          sources: sources,
          savedId: id,
        ),
      );
    } catch (_) {
      throw const FertilizerAssessmentFailure(
        FertilizerAssessmentFailureType.saveFailed,
        'The guidance is ready but could not be saved.',
      );
    }
  }

  Future<void> _retrySave(
    FertilizerAssessmentSaveRetried event,
    Emitter<FertilizerAssessmentState> emit,
  ) async {
    final pending = _pendingAssessment;
    final plant = state.plant;
    if (_inFlight || pending == null || plant == null) return;
    _inFlight = true;
    try {
      await _save(pending, state.sources, plant, emit);
    } on AppError catch (error) {
      emit(
        FertilizerAssessmentState(
          status: FertilizerAssessmentStatus.failure,
          plant: plant,
          lastFertilizingLog: state.lastFertilizingLog,
          growthActivity: pending.growthActivity,
          guidance: pending.guidance,
          sources: state.sources,
          errorMessage: error.message,
          saveRetryAvailable: true,
        ),
      );
    } finally {
      _inFlight = false;
    }
  }
}
