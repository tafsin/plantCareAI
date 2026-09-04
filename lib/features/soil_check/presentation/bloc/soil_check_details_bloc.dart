import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/soil_check/domain/entities/soil_check.dart';
import 'package:plantcare_ai/features/soil_check/domain/repositories/soil_check_repository.dart';
import 'package:plantcare_ai/features/soil_check/domain/services/soil_evidence_validator.dart';
import 'package:plantcare_shared/errors.dart';

sealed class SoilCheckDetailsEvent extends Equatable {
  const SoilCheckDetailsEvent();
  @override
  List<Object?> get props => [];
}

final class SoilCheckDetailsWatchRequested extends SoilCheckDetailsEvent {
  const SoilCheckDetailsWatchRequested(this.plantId, this.soilCheckId);
  final String plantId;
  final String soilCheckId;
  @override
  List<Object?> get props => [plantId, soilCheckId];
}

final class SoilCheckDetailsChanged extends SoilCheckDetailsEvent {
  const SoilCheckDetailsChanged(this.item);
  final SoilCheckRecord? item;
  @override
  List<Object?> get props => [item];
}

final class SoilCheckDetailsFailed extends SoilCheckDetailsEvent {
  const SoilCheckDetailsFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum SoilCheckDetailsStatus { initial, loading, loaded, notFound, failure }

final class SoilCheckDetailsState extends Equatable {
  const SoilCheckDetailsState({
    this.status = SoilCheckDetailsStatus.initial,
    this.item,
    this.sources = const [],
    this.errorMessage,
  });
  final SoilCheckDetailsStatus status;
  final SoilCheckRecord? item;
  final List<KnowledgeSource> sources;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, item, sources, errorMessage];
}

final class SoilCheckDetailsBloc
    extends Bloc<SoilCheckDetailsEvent, SoilCheckDetailsState> {
  SoilCheckDetailsBloc(this._repository, [this._validator])
    : super(const SoilCheckDetailsState()) {
    on<SoilCheckDetailsWatchRequested>(_watch);
    on<SoilCheckDetailsChanged>(_changed);
    on<SoilCheckDetailsFailed>(
      (event, emit) => emit(
        SoilCheckDetailsState(
          status: SoilCheckDetailsStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }
  final SoilCheckRepository _repository;
  final SoilEvidenceValidator? _validator;
  StreamSubscription<SoilCheckRecord?>? _subscription;

  Future<void> _changed(
    SoilCheckDetailsChanged event,
    Emitter<SoilCheckDetailsState> emit,
  ) async {
    final item = event.item;
    if (item == null) {
      emit(
        const SoilCheckDetailsState(status: SoilCheckDetailsStatus.notFound),
      );
      return;
    }
    try {
      final canonicalKey = item.guidance.canonicalPlantKey;
      final evidence = canonicalKey == null || _validator == null
          ? null
          : await _validator.validate(
              canonicalKey,
              item.guidance.evidenceChunkIds,
            );
      emit(
        SoilCheckDetailsState(
          status: SoilCheckDetailsStatus.loaded,
          item: item,
          sources: evidence?.sources ?? const [],
        ),
      );
    } on AppError catch (error) {
      emit(
        SoilCheckDetailsState(
          status: SoilCheckDetailsStatus.failure,
          item: item,
          errorMessage: error.message,
        ),
      );
    }
  }

  Future<void> _watch(
    SoilCheckDetailsWatchRequested event,
    Emitter<SoilCheckDetailsState> emit,
  ) async {
    await _subscription?.cancel();
    emit(const SoilCheckDetailsState(status: SoilCheckDetailsStatus.loading));
    try {
      _subscription = _repository
          .watchDetails(event.plantId, event.soilCheckId)
          .listen(
            (item) => add(SoilCheckDetailsChanged(item)),
            onError: (Object error) => add(
              SoilCheckDetailsFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load this soil check.',
              ),
            ),
          );
    } catch (error) {
      emit(
        SoilCheckDetailsState(
          status: SoilCheckDetailsStatus.failure,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t load this soil check.',
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
