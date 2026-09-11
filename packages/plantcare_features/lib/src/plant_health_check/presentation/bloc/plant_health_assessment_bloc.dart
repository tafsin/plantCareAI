import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_shared/errors.dart';

sealed class PlantHealthAssessmentEvent extends Equatable {
  const PlantHealthAssessmentEvent();

  @override
  List<Object?> get props => [];
}

final class PlantHealthAssessmentWatchRequested
    extends PlantHealthAssessmentEvent {
  const PlantHealthAssessmentWatchRequested(this.plantId, this.observationId);

  final String plantId;
  final String observationId;

  @override
  List<Object?> get props => [plantId, observationId];
}

final class _ObservationChanged extends PlantHealthAssessmentEvent {
  const _ObservationChanged(this.observation);

  final PlantObservation? observation;

  @override
  List<Object?> get props => [observation];
}

final class _DiagnosesChanged extends PlantHealthAssessmentEvent {
  const _DiagnosesChanged(this.diagnoses);

  final List<PlantDiagnosis> diagnoses;

  @override
  List<Object?> get props => [diagnoses];
}

final class _SourcesChanged extends PlantHealthAssessmentEvent {
  const _SourcesChanged(this.sources);

  final List<KnowledgeSource> sources;

  @override
  List<Object?> get props => [sources];
}

final class _AssessmentFailed extends PlantHealthAssessmentEvent {
  const _AssessmentFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

enum PlantHealthAssessmentStatus { initial, loading, notFound, loaded, failure }

final class PlantHealthAssessmentState extends Equatable {
  const PlantHealthAssessmentState({
    this.status = PlantHealthAssessmentStatus.initial,
    this.observation,
    this.diagnosis,
    this.sources = const [],
    this.errorMessage,
  });

  final PlantHealthAssessmentStatus status;
  final PlantObservation? observation;
  final PlantDiagnosis? diagnosis;
  final List<KnowledgeSource> sources;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    status,
    observation,
    diagnosis,
    sources,
    errorMessage,
  ];
}

final class PlantHealthAssessmentBloc
    extends Bloc<PlantHealthAssessmentEvent, PlantHealthAssessmentState> {
  PlantHealthAssessmentBloc(
    this._observationRepository,
    this._diagnosisRepository,
    this._knowledgeRepository,
  ) : super(const PlantHealthAssessmentState()) {
    on<PlantHealthAssessmentWatchRequested>(_onWatch);
    on<_ObservationChanged>(_onObservationChanged);
    on<_DiagnosesChanged>(_onDiagnosesChanged);
    on<_SourcesChanged>(
      (event, emit) => emit(
        PlantHealthAssessmentState(
          status: state.status,
          observation: state.observation,
          diagnosis: state.diagnosis,
          sources: event.sources,
        ),
      ),
    );
    on<_AssessmentFailed>(
      (event, emit) => emit(
        PlantHealthAssessmentState(
          status: PlantHealthAssessmentStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final PlantObservationRepository _observationRepository;
  final PlantDiagnosisRepository _diagnosisRepository;
  final KnowledgeRepository _knowledgeRepository;
  StreamSubscription<PlantObservation?>? _observationSubscription;
  StreamSubscription<List<PlantDiagnosis>>? _diagnosisSubscription;
  String? _plantId;
  String? _observationId;

  Future<void> _onWatch(
    PlantHealthAssessmentWatchRequested event,
    Emitter<PlantHealthAssessmentState> emit,
  ) async {
    await _cancelSubscriptions();
    _plantId = event.plantId;
    _observationId = event.observationId;
    emit(
      const PlantHealthAssessmentState(
        status: PlantHealthAssessmentStatus.loading,
      ),
    );
    _observationSubscription = _observationRepository
        .watchObservation(event.plantId, event.observationId)
        .listen(
          (observation) => add(_ObservationChanged(observation)),
          onError: (Object error) => add(
            _AssessmentFailed(
              error is AppError
                  ? error.message
                  : 'Couldn\'t load this health assessment.',
            ),
          ),
        );
    _diagnosisSubscription = _diagnosisRepository
        .watchDiagnoses(event.plantId, event.observationId)
        .listen(
          (diagnoses) => add(_DiagnosesChanged(diagnoses)),
          onError: (Object error) => add(
            _AssessmentFailed(
              error is AppError
                  ? error.message
                  : 'Couldn\'t load this health assessment.',
            ),
          ),
        );
  }

  void _onObservationChanged(
    _ObservationChanged event,
    Emitter<PlantHealthAssessmentState> emit,
  ) {
    if (event.observation == null) {
      emit(
        const PlantHealthAssessmentState(
          status: PlantHealthAssessmentStatus.notFound,
        ),
      );
      return;
    }
    emit(
      PlantHealthAssessmentState(
        status: PlantHealthAssessmentStatus.loaded,
        observation: event.observation,
        diagnosis: state.diagnosis,
        sources: state.sources,
      ),
    );
  }

  Future<void> _onDiagnosesChanged(
    _DiagnosesChanged event,
    Emitter<PlantHealthAssessmentState> emit,
  ) async {
    final latest = _latestDiagnosis(event.diagnoses);
    emit(
      PlantHealthAssessmentState(
        status: state.observation == null
            ? PlantHealthAssessmentStatus.loading
            : PlantHealthAssessmentStatus.loaded,
        observation: state.observation,
        diagnosis: latest,
      ),
    );
    if (latest == null || latest.sourceIds.isEmpty) return;
    try {
      final sources = await _knowledgeRepository.loadSources(
        latest.sourceIds.toSet(),
      );
      if (_plantId != null && _observationId != null) {
        add(_SourcesChanged(sources.items));
      }
    } on AppError catch (error) {
      add(_AssessmentFailed(error.message));
    } catch (_) {
      add(const _AssessmentFailed('Couldn\'t load trusted source details.'));
    }
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
    await _observationSubscription?.cancel();
    await _diagnosisSubscription?.cancel();
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
