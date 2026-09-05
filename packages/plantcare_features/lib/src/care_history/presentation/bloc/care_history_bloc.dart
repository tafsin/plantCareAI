import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_shared/errors.dart';

sealed class CareHistoryEvent extends Equatable {
  const CareHistoryEvent();
  @override
  List<Object?> get props => [];
}

final class CareHistoryWatchRequested extends CareHistoryEvent {
  const CareHistoryWatchRequested(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

final class CareHistoryChanged extends CareHistoryEvent {
  const CareHistoryChanged(this.logs);
  final List<CareLog> logs;
  @override
  List<Object?> get props => [logs];
}

final class CareHistoryFailed extends CareHistoryEvent {
  const CareHistoryFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum CareHistoryStatus { initial, loading, loaded, failure }

final class CareHistoryState extends Equatable {
  const CareHistoryState({
    this.status = CareHistoryStatus.initial,
    this.logs = const [],
    this.errorMessage,
  });
  final CareHistoryStatus status;
  final List<CareLog> logs;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, logs, errorMessage];
}

final class CareHistoryBloc extends Bloc<CareHistoryEvent, CareHistoryState> {
  CareHistoryBloc(this._repository) : super(const CareHistoryState()) {
    on<CareHistoryWatchRequested>(_watch);
    on<CareHistoryChanged>(
      (event, emit) => emit(
        CareHistoryState(status: CareHistoryStatus.loaded, logs: event.logs),
      ),
    );
    on<CareHistoryFailed>(
      (event, emit) => emit(
        CareHistoryState(
          status: CareHistoryStatus.failure,
          logs: state.logs,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final CareLogRepository _repository;
  StreamSubscription<List<CareLog>>? _subscription;

  Future<void> _watch(
    CareHistoryWatchRequested event,
    Emitter<CareHistoryState> emit,
  ) async {
    await _subscription?.cancel();
    emit(CareHistoryState(status: CareHistoryStatus.loading, logs: state.logs));
    try {
      _subscription = _repository
          .watchForPlant(event.plantId)
          .listen(
            (logs) => add(CareHistoryChanged(logs)),
            onError: (Object error) => add(
              CareHistoryFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load care history. Try again.',
              ),
            ),
          );
    } catch (error) {
      emit(
        CareHistoryState(
          status: CareHistoryStatus.failure,
          logs: state.logs,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t load care history. Try again.',
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
