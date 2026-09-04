import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_shared/errors.dart';

sealed class ObservationHistoryEvent extends Equatable {
  const ObservationHistoryEvent();
  @override
  List<Object?> get props => [];
}

final class ObservationHistoryWatchRequested extends ObservationHistoryEvent {
  const ObservationHistoryWatchRequested(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

final class ObservationHistoryChanged extends ObservationHistoryEvent {
  const ObservationHistoryChanged(this.observations);
  final List<PlantObservation> observations;
  @override
  List<Object?> get props => [observations];
}

final class ObservationHistoryFailed extends ObservationHistoryEvent {
  const ObservationHistoryFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum ObservationHistoryStatus { initial, loading, loaded, failure }

final class ObservationHistoryState extends Equatable {
  const ObservationHistoryState({
    this.status = ObservationHistoryStatus.initial,
    this.observations = const [],
    this.errorMessage,
  });
  final ObservationHistoryStatus status;
  final List<PlantObservation> observations;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, observations, errorMessage];
}

final class ObservationHistoryBloc
    extends Bloc<ObservationHistoryEvent, ObservationHistoryState> {
  ObservationHistoryBloc(this._repository)
    : super(const ObservationHistoryState()) {
    on<ObservationHistoryWatchRequested>(_onWatch);
    on<ObservationHistoryChanged>(
      (event, emit) => emit(
        ObservationHistoryState(
          status: ObservationHistoryStatus.loaded,
          observations: event.observations,
        ),
      ),
    );
    on<ObservationHistoryFailed>(
      (event, emit) => emit(
        ObservationHistoryState(
          status: ObservationHistoryStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final PlantObservationRepository _repository;
  StreamSubscription<List<PlantObservation>>? _subscription;

  Future<void> _onWatch(
    ObservationHistoryWatchRequested event,
    Emitter<ObservationHistoryState> emit,
  ) async {
    await _subscription?.cancel();
    emit(
      const ObservationHistoryState(status: ObservationHistoryStatus.loading),
    );
    try {
      _subscription = _repository
          .watchObservations(event.plantId)
          .listen(
            (items) => add(ObservationHistoryChanged(items)),
            onError: (Object error) => add(
              ObservationHistoryFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load plant observations. Try again.',
              ),
            ),
          );
    } on AppError catch (error) {
      emit(
        ObservationHistoryState(
          status: ObservationHistoryStatus.failure,
          errorMessage: error.message,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
