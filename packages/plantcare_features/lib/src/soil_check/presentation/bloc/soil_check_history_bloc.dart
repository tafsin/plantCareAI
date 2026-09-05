import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/soil_check.dart';
import 'package:plantcare_shared/errors.dart';

sealed class SoilCheckHistoryEvent extends Equatable {
  const SoilCheckHistoryEvent();
  @override
  List<Object?> get props => [];
}

final class SoilCheckHistoryWatchRequested extends SoilCheckHistoryEvent {
  const SoilCheckHistoryWatchRequested(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

final class SoilCheckHistoryChanged extends SoilCheckHistoryEvent {
  const SoilCheckHistoryChanged(this.items);
  final List<SoilCheckRecord> items;
  @override
  List<Object?> get props => [items];
}

final class SoilCheckHistoryFailed extends SoilCheckHistoryEvent {
  const SoilCheckHistoryFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum SoilCheckHistoryStatus { initial, loading, loaded, failure }

final class SoilCheckHistoryState extends Equatable {
  const SoilCheckHistoryState({
    this.status = SoilCheckHistoryStatus.initial,
    this.items = const [],
    this.errorMessage,
  });
  final SoilCheckHistoryStatus status;
  final List<SoilCheckRecord> items;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, items, errorMessage];
}

final class SoilCheckHistoryBloc
    extends Bloc<SoilCheckHistoryEvent, SoilCheckHistoryState> {
  SoilCheckHistoryBloc(this._repository)
    : super(const SoilCheckHistoryState()) {
    on<SoilCheckHistoryWatchRequested>(_watch);
    on<SoilCheckHistoryChanged>(
      (event, emit) => emit(
        SoilCheckHistoryState(
          status: SoilCheckHistoryStatus.loaded,
          items: event.items,
        ),
      ),
    );
    on<SoilCheckHistoryFailed>(
      (event, emit) => emit(
        SoilCheckHistoryState(
          status: SoilCheckHistoryStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }
  final SoilCheckRepository _repository;
  StreamSubscription<List<SoilCheckRecord>>? _subscription;
  Future<void> _watch(
    SoilCheckHistoryWatchRequested event,
    Emitter<SoilCheckHistoryState> emit,
  ) async {
    await _subscription?.cancel();
    emit(const SoilCheckHistoryState(status: SoilCheckHistoryStatus.loading));
    try {
      _subscription = _repository
          .watchHistory(event.plantId)
          .listen(
            (items) => add(SoilCheckHistoryChanged(items)),
            onError: (Object error) => add(
              SoilCheckHistoryFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load soil checks. Try again.',
              ),
            ),
          );
    } catch (error) {
      emit(
        SoilCheckHistoryState(
          status: SoilCheckHistoryStatus.failure,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t load soil checks. Try again.',
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
