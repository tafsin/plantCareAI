import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/plants/domain/repositories/plant_repository.dart';
import 'package:plantcare_shared/errors.dart';

sealed class PlantsEvent extends Equatable {
  const PlantsEvent();
  @override
  List<Object?> get props => [];
}

final class PlantsWatchRequested extends PlantsEvent {
  const PlantsWatchRequested();
}

final class PlantsChanged extends PlantsEvent {
  const PlantsChanged(this.plants);
  final List<Plant> plants;
  @override
  List<Object?> get props => [plants];
}

final class PlantsWatchFailed extends PlantsEvent {
  const PlantsWatchFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

final class PlantDeleteRequested extends PlantsEvent {
  const PlantDeleteRequested(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

enum PlantsStatus { initial, loading, empty, loaded, failure }

final class PlantsState extends Equatable {
  const PlantsState({
    this.status = PlantsStatus.initial,
    this.plants = const [],
    this.errorMessage,
    this.deletingPlantIds = const {},
    this.deletedPlantId,
    this.deleteFailureMessage,
    this.actionRevision = 0,
  });

  final PlantsStatus status;
  final List<Plant> plants;
  final String? errorMessage;
  final Set<String> deletingPlantIds;
  final String? deletedPlantId;
  final String? deleteFailureMessage;
  final int actionRevision;

  PlantsState copyWith({
    PlantsStatus? status,
    List<Plant>? plants,
    String? errorMessage,
    bool clearErrorMessage = false,
    Set<String>? deletingPlantIds,
    String? deletedPlantId,
    bool clearDeletedPlantId = false,
    String? deleteFailureMessage,
    bool clearDeleteFailure = false,
    int? actionRevision,
  }) => PlantsState(
    status: status ?? this.status,
    plants: plants ?? this.plants,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    deletingPlantIds: deletingPlantIds ?? this.deletingPlantIds,
    deletedPlantId: clearDeletedPlantId
        ? null
        : deletedPlantId ?? this.deletedPlantId,
    deleteFailureMessage: clearDeleteFailure
        ? null
        : deleteFailureMessage ?? this.deleteFailureMessage,
    actionRevision: actionRevision ?? this.actionRevision,
  );

  @override
  List<Object?> get props => [
    status,
    plants,
    errorMessage,
    deletingPlantIds,
    deletedPlantId,
    deleteFailureMessage,
    actionRevision,
  ];
}

final class PlantsBloc extends Bloc<PlantsEvent, PlantsState> {
  PlantsBloc(this._repository) : super(const PlantsState()) {
    on<PlantsWatchRequested>(_onWatchRequested);
    on<PlantsChanged>(_onChanged);
    on<PlantsWatchFailed>(_onWatchFailed);
    on<PlantDeleteRequested>(_onDeleteRequested);
  }

  final PlantRepository _repository;
  StreamSubscription<List<Plant>>? _subscription;

  Future<void> _onWatchRequested(
    PlantsWatchRequested event,
    Emitter<PlantsState> emit,
  ) async {
    await _subscription?.cancel();
    emit(state.copyWith(status: PlantsStatus.loading, clearErrorMessage: true));
    try {
      _subscription = _repository.watchPlants().listen(
        (plants) => add(PlantsChanged(plants)),
        onError: (Object error) => add(
          PlantsWatchFailed(
            error is AppError
                ? error.message
                : 'Couldn\'t load your plants. Please try again.',
          ),
        ),
      );
    } on AppError catch (error) {
      emit(
        state.copyWith(
          status: PlantsStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PlantsStatus.failure,
          errorMessage: 'Couldn\'t load your plants. Please try again.',
        ),
      );
    }
  }

  void _onChanged(PlantsChanged event, Emitter<PlantsState> emit) {
    emit(
      state.copyWith(
        status: event.plants.isEmpty ? PlantsStatus.empty : PlantsStatus.loaded,
        plants: List.unmodifiable(event.plants),
        clearErrorMessage: true,
      ),
    );
  }

  void _onWatchFailed(PlantsWatchFailed event, Emitter<PlantsState> emit) {
    emit(
      state.copyWith(status: PlantsStatus.failure, errorMessage: event.message),
    );
  }

  Future<void> _onDeleteRequested(
    PlantDeleteRequested event,
    Emitter<PlantsState> emit,
  ) async {
    if (state.deletingPlantIds.contains(event.plantId)) return;
    emit(
      state.copyWith(
        deletingPlantIds: {...state.deletingPlantIds, event.plantId},
        clearDeletedPlantId: true,
        clearDeleteFailure: true,
      ),
    );
    try {
      await _repository.deletePlant(event.plantId);
      final deletingIds = {...state.deletingPlantIds}..remove(event.plantId);
      emit(
        state.copyWith(
          deletingPlantIds: deletingIds,
          deletedPlantId: event.plantId,
          actionRevision: state.actionRevision + 1,
        ),
      );
    } on AppError catch (error) {
      _emitDeleteFailure(event.plantId, error.message, emit);
    } catch (_) {
      _emitDeleteFailure(
        event.plantId,
        'Couldn\'t delete this plant. Please try again.',
        emit,
      );
    }
  }

  void _emitDeleteFailure(
    String plantId,
    String message,
    Emitter<PlantsState> emit,
  ) {
    final deletingIds = {...state.deletingPlantIds}..remove(plantId);
    emit(
      state.copyWith(
        deletingPlantIds: deletingIds,
        deleteFailureMessage: message,
        actionRevision: state.actionRevision + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
