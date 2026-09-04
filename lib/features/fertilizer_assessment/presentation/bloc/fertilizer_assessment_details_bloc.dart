import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/entities/fertilizer_assessment.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/repositories/fertilizer_assessment_repository.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/services/fertilizer_evidence_validator.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';

sealed class FertilizerAssessmentDetailsEvent extends Equatable {
  const FertilizerAssessmentDetailsEvent();
  @override
  List<Object?> get props => [];
}

final class FertilizerAssessmentDetailsWatchRequested
    extends FertilizerAssessmentDetailsEvent {
  const FertilizerAssessmentDetailsWatchRequested(
    this.plantId,
    this.assessmentId,
  );
  final String plantId;
  final String assessmentId;
  @override
  List<Object?> get props => [plantId, assessmentId];
}

final class FertilizerAssessmentDetailsChanged
    extends FertilizerAssessmentDetailsEvent {
  const FertilizerAssessmentDetailsChanged(this.item);
  final FertilizerAssessment? item;
  @override
  List<Object?> get props => [item];
}

final class FertilizerAssessmentDetailsFailed
    extends FertilizerAssessmentDetailsEvent {
  const FertilizerAssessmentDetailsFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum FertilizerAssessmentDetailsStatus {
  initial,
  loading,
  loaded,
  notFound,
  failure,
}

final class FertilizerAssessmentDetailsState extends Equatable {
  const FertilizerAssessmentDetailsState({
    this.status = FertilizerAssessmentDetailsStatus.initial,
    this.item,
    this.sources = const [],
    this.errorMessage,
  });
  final FertilizerAssessmentDetailsStatus status;
  final FertilizerAssessment? item;
  final List<KnowledgeSource> sources;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, item, sources, errorMessage];
}

final class FertilizerAssessmentDetailsBloc
    extends
        Bloc<
          FertilizerAssessmentDetailsEvent,
          FertilizerAssessmentDetailsState
        > {
  FertilizerAssessmentDetailsBloc(this._repository, this._validator)
    : super(const FertilizerAssessmentDetailsState()) {
    on<FertilizerAssessmentDetailsWatchRequested>(_watch);
    on<FertilizerAssessmentDetailsChanged>(_changed);
    on<FertilizerAssessmentDetailsFailed>(
      (event, emit) => emit(
        FertilizerAssessmentDetailsState(
          status: FertilizerAssessmentDetailsStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final FertilizerAssessmentRepository _repository;
  final FertilizerEvidenceValidator _validator;
  StreamSubscription<FertilizerAssessment?>? _subscription;

  Future<void> _changed(
    FertilizerAssessmentDetailsChanged event,
    Emitter<FertilizerAssessmentDetailsState> emit,
  ) async {
    final item = event.item;
    if (item == null) {
      emit(
        const FertilizerAssessmentDetailsState(
          status: FertilizerAssessmentDetailsStatus.notFound,
        ),
      );
      return;
    }
    try {
      final evidence = await _validator.validate(
        item.guidance.canonicalPlantKey!,
        item.guidance.evidenceChunkIds,
      );
      emit(
        FertilizerAssessmentDetailsState(
          status: FertilizerAssessmentDetailsStatus.loaded,
          item: item,
          sources: evidence.sources,
        ),
      );
    } on AppError catch (error) {
      emit(
        FertilizerAssessmentDetailsState(
          status: FertilizerAssessmentDetailsStatus.failure,
          item: item,
          errorMessage: error.message,
        ),
      );
    }
  }

  Future<void> _watch(
    FertilizerAssessmentDetailsWatchRequested event,
    Emitter<FertilizerAssessmentDetailsState> emit,
  ) async {
    await _subscription?.cancel();
    emit(
      const FertilizerAssessmentDetailsState(
        status: FertilizerAssessmentDetailsStatus.loading,
      ),
    );
    try {
      _subscription = _repository
          .watchDetails(event.plantId, event.assessmentId)
          .listen(
            (item) => add(FertilizerAssessmentDetailsChanged(item)),
            onError: (Object error) => add(
              FertilizerAssessmentDetailsFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load this fertilizer assessment.',
              ),
            ),
          );
    } catch (error) {
      emit(
        FertilizerAssessmentDetailsState(
          status: FertilizerAssessmentDetailsStatus.failure,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t load this fertilizer assessment.',
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
