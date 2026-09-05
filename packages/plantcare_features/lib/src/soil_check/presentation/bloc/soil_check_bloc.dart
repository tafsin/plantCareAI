import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/soil_check.dart';
import 'package:plantcare_shared/errors.dart';

sealed class SoilCheckEvent extends Equatable {
  const SoilCheckEvent();
  @override
  List<Object?> get props => [];
}

final class SoilCheckStarted extends SoilCheckEvent {
  const SoilCheckStarted(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

final class SoilCheckPlantChanged extends SoilCheckEvent {
  const SoilCheckPlantChanged(this.plant);
  final Plant? plant;
  @override
  List<Object?> get props => [plant];
}

final class SoilCheckMoistureSelected extends SoilCheckEvent {
  const SoilCheckMoistureSelected(this.level);
  final SoilMoistureLevel level;
  @override
  List<Object?> get props => [level];
}

final class SoilCheckSubmitted extends SoilCheckEvent {
  const SoilCheckSubmitted({required this.checkTime});
  final DateTime checkTime;
  @override
  List<Object?> get props => [checkTime];
}

final class SoilCheckSaveRetried extends SoilCheckEvent {
  const SoilCheckSaveRetried();
}

enum SoilCheckStatus {
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

final class SoilCheckState extends Equatable {
  const SoilCheckState({
    this.status = SoilCheckStatus.initial,
    this.plant,
    this.moistureLevel,
    this.guidance,
    this.sources = const [],
    this.savedId,
    this.errorMessage,
    this.saveRetryAvailable = false,
  });

  final SoilCheckStatus status;
  final Plant? plant;
  final SoilMoistureLevel? moistureLevel;
  final WateringGuidance? guidance;
  final List<KnowledgeSource> sources;
  final String? savedId;
  final String? errorMessage;
  final bool saveRetryAvailable;

  @override
  List<Object?> get props => [
    status,
    plant,
    moistureLevel,
    guidance,
    sources,
    savedId,
    errorMessage,
    saveRetryAvailable,
  ];
}

final class SoilCheckBloc extends Bloc<SoilCheckEvent, SoilCheckState> {
  SoilCheckBloc(
    this._plantRepository,
    this._repository,
    this._validator,
    this._engine,
  ) : super(const SoilCheckState()) {
    on<SoilCheckStarted>(_onStarted);
    on<SoilCheckPlantChanged>(_onPlantChanged);
    on<SoilCheckMoistureSelected>(_onMoistureSelected);
    on<SoilCheckSubmitted>(_onSubmitted);
    on<SoilCheckSaveRetried>(_onSaveRetried);
  }

  final PlantRepository _plantRepository;
  final SoilCheckRepository _repository;
  final SoilEvidenceValidator _validator;
  final DeterministicWateringEngine _engine;
  StreamSubscription<Plant?>? _plantSubscription;
  String? _plantId;
  SoilCheckRecord? _pendingRecord;
  bool _inFlight = false;

  Future<void> _onStarted(
    SoilCheckStarted event,
    Emitter<SoilCheckState> emit,
  ) async {
    await _plantSubscription?.cancel();
    _plantId = event.plantId;
    emit(const SoilCheckState(status: SoilCheckStatus.loading));
    try {
      _plantSubscription = _plantRepository
          .watchPlant(event.plantId)
          .listen(
            (plant) => add(SoilCheckPlantChanged(plant)),
            onError: (Object error) => add(const SoilCheckPlantChanged(null)),
          );
    } catch (_) {
      emit(
        const SoilCheckState(
          status: SoilCheckStatus.failure,
          errorMessage: 'Couldn\'t load this plant.',
        ),
      );
    }
  }

  void _onPlantChanged(
    SoilCheckPlantChanged event,
    Emitter<SoilCheckState> emit,
  ) {
    if (event.plant == null) {
      emit(
        const SoilCheckState(
          status: SoilCheckStatus.failure,
          errorMessage: 'Plant not found.',
        ),
      );
      return;
    }
    emit(
      SoilCheckState(
        status: SoilCheckStatus.ready,
        plant: event.plant,
        moistureLevel: state.moistureLevel,
      ),
    );
  }

  void _onMoistureSelected(
    SoilCheckMoistureSelected event,
    Emitter<SoilCheckState> emit,
  ) {
    if (_inFlight || state.plant == null) return;
    _pendingRecord = null;
    emit(
      SoilCheckState(
        status: SoilCheckStatus.ready,
        plant: state.plant,
        moistureLevel: event.level,
      ),
    );
  }

  Future<void> _onSubmitted(
    SoilCheckSubmitted event,
    Emitter<SoilCheckState> emit,
  ) async {
    final plant = state.plant;
    final moisture = state.moistureLevel;
    if (_inFlight ||
        state.status != SoilCheckStatus.ready ||
        plant == null ||
        moisture == null) {
      return;
    }
    _inFlight = true;
    emit(
      SoilCheckState(
        status: SoilCheckStatus.calculating,
        plant: plant,
        moistureLevel: moisture,
      ),
    );
    try {
      final canonicalKey =
          canonicalPlantKeyFor(plant.scientificName) ??
          canonicalPlantKeyFor(plant.commonName);
      final guidance = _engine.calculate(
        WateringGuidanceInput(
          canonicalPlantKey: canonicalKey,
          environment: plant.environment,
          growingMedium: plant.growingMedium,
          moistureLevel: moisture,
          checkTime: event.checkTime,
        ),
      );
      if (guidance.outcome == WateringOutcome.unsupportedPlant) {
        emit(
          SoilCheckState(
            status: SoilCheckStatus.unsupportedPlant,
            plant: plant,
            moistureLevel: moisture,
            guidance: guidance,
          ),
        );
        return;
      }
      emit(
        SoilCheckState(
          status: SoilCheckStatus.resultReady,
          plant: plant,
          moistureLevel: moisture,
          guidance: guidance,
        ),
      );
      final evidence = await _validator.validate(
        guidance.canonicalPlantKey!,
        guidance.evidenceChunkIds,
      );
      final record = SoilCheckRecord(
        id: '',
        moistureLevel: moisture,
        guidance: guidance,
        environmentSnapshot: plant.environment,
        growingMediumSnapshot: plant.growingMedium,
        createdAt: event.checkTime,
        suggestedCheckAt: guidance.suggestedCheckAfter == null
            ? null
            : event.checkTime.add(guidance.suggestedCheckAfter!),
      );
      _pendingRecord = record;
      await _save(record, evidence.sources, plant, emit);
    } on AppError catch (error) {
      emit(
        SoilCheckState(
          status: SoilCheckStatus.failure,
          plant: plant,
          moistureLevel: moisture,
          guidance: state.guidance,
          sources: state.sources,
          errorMessage: error.message,
          saveRetryAvailable: _pendingRecord != null,
        ),
      );
    } catch (_) {
      emit(
        SoilCheckState(
          status: SoilCheckStatus.failure,
          plant: plant,
          moistureLevel: moisture,
          guidance: state.guidance,
          errorMessage: 'Couldn\'t complete this soil check. Try again.',
        ),
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _save(
    SoilCheckRecord record,
    List<KnowledgeSource> sources,
    Plant plant,
    Emitter<SoilCheckState> emit,
  ) async {
    emit(
      SoilCheckState(
        status: SoilCheckStatus.saving,
        plant: plant,
        moistureLevel: record.moistureLevel,
        guidance: record.guidance,
        sources: sources,
      ),
    );
    try {
      final id = await _repository.save(_plantId!, record);
      emit(
        SoilCheckState(
          status: SoilCheckStatus.saved,
          plant: plant,
          moistureLevel: record.moistureLevel,
          guidance: record.guidance,
          sources: sources,
          savedId: id,
        ),
      );
    } catch (_) {
      throw const SoilCheckFailure(
        SoilCheckFailureType.saveFailed,
        'The recommendation is ready but could not be saved.',
      );
    }
  }

  Future<void> _onSaveRetried(
    SoilCheckSaveRetried event,
    Emitter<SoilCheckState> emit,
  ) async {
    final record = _pendingRecord;
    final plant = state.plant;
    if (_inFlight || record == null || plant == null) return;
    _inFlight = true;
    try {
      await _save(record, state.sources, plant, emit);
    } on AppError catch (error) {
      emit(
        SoilCheckState(
          status: SoilCheckStatus.failure,
          plant: plant,
          moistureLevel: record.moistureLevel,
          guidance: record.guidance,
          sources: state.sources,
          errorMessage: error.message,
          saveRetryAvailable: true,
        ),
      );
    } finally {
      _inFlight = false;
    }
  }

  @override
  Future<void> close() async {
    await _plantSubscription?.cancel();
    return super.close();
  }
}
