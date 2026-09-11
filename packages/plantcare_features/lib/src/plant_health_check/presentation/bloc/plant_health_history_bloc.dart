import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_shared/errors.dart';

sealed class PlantHealthHistoryEvent extends Equatable {
  const PlantHealthHistoryEvent();

  @override
  List<Object?> get props => [];
}

final class PlantHealthHistoryWatchRequested extends PlantHealthHistoryEvent {
  const PlantHealthHistoryWatchRequested(this.plantId);

  final String plantId;

  @override
  List<Object?> get props => [plantId];
}

final class PlantHealthHistoryChanged extends PlantHealthHistoryEvent {
  const PlantHealthHistoryChanged(this.entries);

  final List<PlantHealthHistoryEntry> entries;

  @override
  List<Object?> get props => [entries];
}

final class PlantHealthHistoryFailed extends PlantHealthHistoryEvent {
  const PlantHealthHistoryFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

enum PlantHealthHistoryStatus { initial, loading, loaded, failure }

enum PlantHealthHistoryAssessmentState {
  complete,
  needsAnotherPhoto,
  insufficientEvidence,
  incomplete,
}

final class PlantHealthHistoryEntry extends Equatable {
  const PlantHealthHistoryEntry({
    required this.observation,
    this.latestDiagnosis,
  });

  final PlantObservation observation;
  final PlantDiagnosis? latestDiagnosis;

  PlantHealthHistoryAssessmentState get assessmentState {
    final diagnosis = latestDiagnosis;
    if (diagnosis == null) return PlantHealthHistoryAssessmentState.incomplete;
    if (diagnosis.status == DiagnosisStatus.insufficientEvidence) {
      return PlantHealthHistoryAssessmentState.insufficientEvidence;
    }
    if (diagnosis.followUp.anotherPhotoHelpful) {
      return PlantHealthHistoryAssessmentState.needsAnotherPhoto;
    }
    return PlantHealthHistoryAssessmentState.complete;
  }

  @override
  List<Object?> get props => [observation, latestDiagnosis];
}

final class PlantHealthHistoryState extends Equatable {
  const PlantHealthHistoryState({
    this.status = PlantHealthHistoryStatus.initial,
    this.entries = const [],
    this.errorMessage,
  });

  final PlantHealthHistoryStatus status;
  final List<PlantHealthHistoryEntry> entries;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, entries, errorMessage];
}

final class PlantHealthHistoryBloc
    extends Bloc<PlantHealthHistoryEvent, PlantHealthHistoryState> {
  PlantHealthHistoryBloc(this._observationRepository, this._diagnosisRepository)
    : super(const PlantHealthHistoryState()) {
    on<PlantHealthHistoryWatchRequested>(_onWatch);
    on<PlantHealthHistoryChanged>(
      (event, emit) => emit(
        PlantHealthHistoryState(
          status: PlantHealthHistoryStatus.loaded,
          entries: event.entries,
        ),
      ),
    );
    on<PlantHealthHistoryFailed>(
      (event, emit) => emit(
        PlantHealthHistoryState(
          status: PlantHealthHistoryStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final PlantObservationRepository _observationRepository;
  final PlantDiagnosisRepository _diagnosisRepository;
  StreamSubscription<List<PlantObservation>>? _observationsSubscription;
  final Map<String, StreamSubscription<List<PlantDiagnosis>>>
  _diagnosisSubscriptions = {};
  List<PlantObservation> _observations = const [];
  final Map<String, List<PlantDiagnosis>> _diagnosesByObservation = {};
  String? _plantId;

  Future<void> _onWatch(
    PlantHealthHistoryWatchRequested event,
    Emitter<PlantHealthHistoryState> emit,
  ) async {
    await _cancelSubscriptions();
    _plantId = event.plantId;
    _observations = const [];
    _diagnosesByObservation.clear();
    emit(
      const PlantHealthHistoryState(status: PlantHealthHistoryStatus.loading),
    );
    try {
      _observationsSubscription = _observationRepository
          .watchObservations(event.plantId)
          .listen(
            _handleObservations,
            onError: (Object error) => add(
              PlantHealthHistoryFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load health history. Try again.',
              ),
            ),
          );
    } on AppError catch (error) {
      emit(
        PlantHealthHistoryState(
          status: PlantHealthHistoryStatus.failure,
          errorMessage: error.message,
        ),
      );
    }
  }

  void _handleObservations(List<PlantObservation> observations) {
    final plantId = _plantId;
    if (plantId == null) return;
    _observations = observations;
    final observationIds = observations.map((item) => item.id).toSet();
    for (final id in _diagnosisSubscriptions.keys.toList()) {
      if (!observationIds.contains(id)) {
        _diagnosisSubscriptions.remove(id)?.cancel();
        _diagnosesByObservation.remove(id);
      }
    }
    for (final observation in observations) {
      if (observation.id.isEmpty ||
          _diagnosisSubscriptions.containsKey(observation.id)) {
        continue;
      }
      _diagnosisSubscriptions[observation.id] = _diagnosisRepository
          .watchDiagnoses(plantId, observation.id)
          .listen(
            (items) {
              _diagnosesByObservation[observation.id] = items;
              _publishEntries();
            },
            onError: (Object error) => add(
              PlantHealthHistoryFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load health assessments. Try again.',
              ),
            ),
          );
    }
    _publishEntries();
  }

  void _publishEntries() {
    add(
      PlantHealthHistoryChanged(
        _observations
            .map(
              (observation) => PlantHealthHistoryEntry(
                observation: observation,
                latestDiagnosis: _latestDiagnosis(
                  _diagnosesByObservation[observation.id] ?? const [],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  PlantDiagnosis? _latestDiagnosis(List<PlantDiagnosis> items) {
    if (items.isEmpty) return null;
    final sorted = [...items]
      ..sort((a, b) {
        final dateCompare =
            (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
        return dateCompare == 0 ? b.id.compareTo(a.id) : dateCompare;
      });
    return sorted.first;
  }

  Future<void> _cancelSubscriptions() async {
    await _observationsSubscription?.cancel();
    for (final subscription in _diagnosisSubscriptions.values) {
      await subscription.cancel();
    }
    _diagnosisSubscriptions.clear();
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
