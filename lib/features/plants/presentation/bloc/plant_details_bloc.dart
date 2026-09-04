import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_shared/errors.dart';

sealed class PlantDetailsEvent extends Equatable {
  const PlantDetailsEvent();
  @override
  List<Object?> get props => [];
}

final class PlantDetailsWatchRequested extends PlantDetailsEvent {
  const PlantDetailsWatchRequested(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

final class PlantDetailsChanged extends PlantDetailsEvent {
  const PlantDetailsChanged(this.plant);
  final Plant? plant;
  @override
  List<Object?> get props => [plant];
}

final class PlantDetailsFailed extends PlantDetailsEvent {
  const PlantDetailsFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum PlantDetailsStatus { initial, loading, loaded, notFound, failure }

final class PlantDetailsState extends Equatable {
  const PlantDetailsState({
    this.status = PlantDetailsStatus.initial,
    this.plant,
    this.errorMessage,
  });

  final PlantDetailsStatus status;
  final Plant? plant;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, plant, errorMessage];
}

final class PlantDetailsBloc
    extends Bloc<PlantDetailsEvent, PlantDetailsState> {
  PlantDetailsBloc(this._repository) : super(const PlantDetailsState()) {
    on<PlantDetailsWatchRequested>(_onWatchRequested);
    on<PlantDetailsChanged>((event, emit) {
      emit(
        PlantDetailsState(
          status: event.plant == null
              ? PlantDetailsStatus.notFound
              : PlantDetailsStatus.loaded,
          plant: event.plant,
        ),
      );
    });
    on<PlantDetailsFailed>((event, emit) {
      emit(
        PlantDetailsState(
          status: PlantDetailsStatus.failure,
          errorMessage: event.message,
        ),
      );
    });
  }

  final PlantRepository _repository;
  StreamSubscription<Plant?>? _subscription;

  Future<void> _onWatchRequested(
    PlantDetailsWatchRequested event,
    Emitter<PlantDetailsState> emit,
  ) async {
    await _subscription?.cancel();
    emit(const PlantDetailsState(status: PlantDetailsStatus.loading));
    if (event.plantId.trim().isEmpty || event.plantId.contains('/')) {
      emit(const PlantDetailsState(status: PlantDetailsStatus.notFound));
      return;
    }
    try {
      _subscription = _repository
          .watchPlant(event.plantId)
          .listen(
            (plant) => add(PlantDetailsChanged(plant)),
            onError: (Object error) => add(
              PlantDetailsFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load this plant. Please try again.',
              ),
            ),
          );
    } on AppError catch (error) {
      emit(
        PlantDetailsState(
          status: PlantDetailsStatus.failure,
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
