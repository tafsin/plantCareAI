import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/entities/fertilizer_assessment.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/repositories/fertilizer_assessment_repository.dart';

sealed class FertilizerAssessmentHistoryEvent extends Equatable {
  const FertilizerAssessmentHistoryEvent();
  @override
  List<Object?> get props => [];
}

final class FertilizerAssessmentHistoryWatchRequested
    extends FertilizerAssessmentHistoryEvent {
  const FertilizerAssessmentHistoryWatchRequested(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

final class FertilizerAssessmentHistoryChanged
    extends FertilizerAssessmentHistoryEvent {
  const FertilizerAssessmentHistoryChanged(this.items);
  final List<FertilizerAssessment> items;
  @override
  List<Object?> get props => [items];
}

final class FertilizerAssessmentHistoryFailed
    extends FertilizerAssessmentHistoryEvent {
  const FertilizerAssessmentHistoryFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum FertilizerAssessmentHistoryStatus { initial, loading, loaded, failure }

final class FertilizerAssessmentHistoryState extends Equatable {
  const FertilizerAssessmentHistoryState({
    this.status = FertilizerAssessmentHistoryStatus.initial,
    this.items = const [],
    this.errorMessage,
  });
  final FertilizerAssessmentHistoryStatus status;
  final List<FertilizerAssessment> items;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, items, errorMessage];
}

final class FertilizerAssessmentHistoryBloc
    extends
        Bloc<
          FertilizerAssessmentHistoryEvent,
          FertilizerAssessmentHistoryState
        > {
  FertilizerAssessmentHistoryBloc(this._repository)
    : super(const FertilizerAssessmentHistoryState()) {
    on<FertilizerAssessmentHistoryWatchRequested>(_watch);
    on<FertilizerAssessmentHistoryChanged>(
      (event, emit) => emit(
        FertilizerAssessmentHistoryState(
          status: FertilizerAssessmentHistoryStatus.loaded,
          items: event.items,
        ),
      ),
    );
    on<FertilizerAssessmentHistoryFailed>(
      (event, emit) => emit(
        FertilizerAssessmentHistoryState(
          status: FertilizerAssessmentHistoryStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final FertilizerAssessmentRepository _repository;
  StreamSubscription<List<FertilizerAssessment>>? _subscription;

  Future<void> _watch(
    FertilizerAssessmentHistoryWatchRequested event,
    Emitter<FertilizerAssessmentHistoryState> emit,
  ) async {
    await _subscription?.cancel();
    emit(
      const FertilizerAssessmentHistoryState(
        status: FertilizerAssessmentHistoryStatus.loading,
      ),
    );
    try {
      _subscription = _repository
          .watchHistory(event.plantId)
          .listen(
            (items) => add(FertilizerAssessmentHistoryChanged(items)),
            onError: (Object error) => add(
              FertilizerAssessmentHistoryFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load fertilizer assessment history.',
              ),
            ),
          );
    } catch (error) {
      emit(
        FertilizerAssessmentHistoryState(
          status: FertilizerAssessmentHistoryStatus.failure,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t load fertilizer assessment history.',
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
