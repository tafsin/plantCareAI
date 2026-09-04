import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plant_observation/domain/repositories/plant_observation_repository.dart';

sealed class ObservationDetailsEvent extends Equatable {
  const ObservationDetailsEvent();
  @override
  List<Object?> get props => [];
}

final class ObservationDetailsWatchRequested extends ObservationDetailsEvent {
  const ObservationDetailsWatchRequested(this.plantId, this.observationId);
  final String plantId;
  final String observationId;
  @override
  List<Object?> get props => [plantId, observationId];
}

final class ObservationDetailsChanged extends ObservationDetailsEvent {
  const ObservationDetailsChanged(this.observation);
  final PlantObservation? observation;
  @override
  List<Object?> get props => [observation];
}

final class ObservationDetailsFailed extends ObservationDetailsEvent {
  const ObservationDetailsFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum ObservationDetailsStatus { initial, loading, loaded, notFound, failure }

final class ObservationDetailsState extends Equatable {
  const ObservationDetailsState({
    this.status = ObservationDetailsStatus.initial,
    this.observation,
    this.errorMessage,
  });
  final ObservationDetailsStatus status;
  final PlantObservation? observation;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, observation, errorMessage];
}

final class ObservationDetailsBloc
    extends Bloc<ObservationDetailsEvent, ObservationDetailsState> {
  ObservationDetailsBloc(this._repository)
    : super(const ObservationDetailsState()) {
    on<ObservationDetailsWatchRequested>(_onWatch);
    on<ObservationDetailsChanged>(
      (event, emit) => emit(
        ObservationDetailsState(
          status: event.observation == null
              ? ObservationDetailsStatus.notFound
              : ObservationDetailsStatus.loaded,
          observation: event.observation,
        ),
      ),
    );
    on<ObservationDetailsFailed>(
      (event, emit) => emit(
        ObservationDetailsState(
          status: ObservationDetailsStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final PlantObservationRepository _repository;
  StreamSubscription<PlantObservation?>? _subscription;

  Future<void> _onWatch(
    ObservationDetailsWatchRequested event,
    Emitter<ObservationDetailsState> emit,
  ) async {
    await _subscription?.cancel();
    emit(
      const ObservationDetailsState(status: ObservationDetailsStatus.loading),
    );
    try {
      _subscription = _repository
          .watchObservation(event.plantId, event.observationId)
          .listen(
            (item) => add(ObservationDetailsChanged(item)),
            onError: (Object error) => add(
              ObservationDetailsFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load this observation. Try again.',
              ),
            ),
          );
    } on AppError catch (error) {
      emit(
        ObservationDetailsState(
          status: ObservationDetailsStatus.failure,
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
