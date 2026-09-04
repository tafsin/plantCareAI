import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_shared/errors.dart';

sealed class DiagnosisHistoryEvent extends Equatable {
  const DiagnosisHistoryEvent();
  @override
  List<Object?> get props => [];
}

final class DiagnosisHistoryWatchRequested extends DiagnosisHistoryEvent {
  const DiagnosisHistoryWatchRequested(this.plantId, this.observationId);
  final String plantId;
  final String observationId;
  @override
  List<Object?> get props => [plantId, observationId];
}

final class DiagnosisHistoryChanged extends DiagnosisHistoryEvent {
  const DiagnosisHistoryChanged(this.items);
  final List<PlantDiagnosis> items;
  @override
  List<Object?> get props => [items];
}

final class DiagnosisHistoryFailed extends DiagnosisHistoryEvent {
  const DiagnosisHistoryFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum DiagnosisHistoryStatus { initial, loading, loaded, failure }

final class DiagnosisHistoryState extends Equatable {
  const DiagnosisHistoryState({
    this.status = DiagnosisHistoryStatus.initial,
    this.items = const [],
    this.errorMessage,
  });
  final DiagnosisHistoryStatus status;
  final List<PlantDiagnosis> items;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, items, errorMessage];
}

final class DiagnosisHistoryBloc
    extends Bloc<DiagnosisHistoryEvent, DiagnosisHistoryState> {
  DiagnosisHistoryBloc(this._repository)
    : super(const DiagnosisHistoryState()) {
    on<DiagnosisHistoryWatchRequested>(_onWatch);
    on<DiagnosisHistoryChanged>(
      (event, emit) => emit(
        DiagnosisHistoryState(
          status: DiagnosisHistoryStatus.loaded,
          items: event.items,
        ),
      ),
    );
    on<DiagnosisHistoryFailed>(
      (event, emit) => emit(
        DiagnosisHistoryState(
          status: DiagnosisHistoryStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final PlantDiagnosisRepository _repository;
  StreamSubscription<List<PlantDiagnosis>>? _subscription;

  Future<void> _onWatch(
    DiagnosisHistoryWatchRequested event,
    Emitter<DiagnosisHistoryState> emit,
  ) async {
    await _subscription?.cancel();
    emit(const DiagnosisHistoryState(status: DiagnosisHistoryStatus.loading));
    try {
      _subscription = _repository
          .watchDiagnoses(event.plantId, event.observationId)
          .listen(
            (items) => add(DiagnosisHistoryChanged(items)),
            onError: (Object error) => add(
              DiagnosisHistoryFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load diagnosis history. Try again.',
              ),
            ),
          );
    } on AppError catch (error) {
      emit(
        DiagnosisHistoryState(
          status: DiagnosisHistoryStatus.failure,
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
