import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_shared/errors.dart';

sealed class DiagnosisDetailsEvent extends Equatable {
  const DiagnosisDetailsEvent();
  @override
  List<Object?> get props => [];
}

final class DiagnosisDetailsWatchRequested extends DiagnosisDetailsEvent {
  const DiagnosisDetailsWatchRequested(
    this.plantId,
    this.observationId,
    this.diagnosisId,
  );
  final String plantId;
  final String observationId;
  final String diagnosisId;
  @override
  List<Object?> get props => [plantId, observationId, diagnosisId];
}

final class DiagnosisDetailsChanged extends DiagnosisDetailsEvent {
  const DiagnosisDetailsChanged(this.item);
  final PlantDiagnosis? item;
  @override
  List<Object?> get props => [item];
}

final class DiagnosisDetailsFailed extends DiagnosisDetailsEvent {
  const DiagnosisDetailsFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum DiagnosisDetailsStatus { initial, loading, loaded, notFound, failure }

final class DiagnosisDetailsState extends Equatable {
  const DiagnosisDetailsState({
    this.status = DiagnosisDetailsStatus.initial,
    this.item,
    this.errorMessage,
    this.sources = const [],
  });
  final DiagnosisDetailsStatus status;
  final PlantDiagnosis? item;
  final String? errorMessage;
  final List<KnowledgeSource> sources;
  @override
  List<Object?> get props => [status, item, errorMessage, sources];
}

final class DiagnosisDetailsBloc
    extends Bloc<DiagnosisDetailsEvent, DiagnosisDetailsState> {
  DiagnosisDetailsBloc(this._repository, this._knowledgeRepository)
    : super(const DiagnosisDetailsState()) {
    on<DiagnosisDetailsWatchRequested>(_onWatch);
    on<DiagnosisDetailsChanged>(_onChanged);
    on<DiagnosisDetailsFailed>(
      (event, emit) => emit(
        DiagnosisDetailsState(
          status: DiagnosisDetailsStatus.failure,
          errorMessage: event.message,
        ),
      ),
    );
  }

  final PlantDiagnosisRepository _repository;
  final KnowledgeRepository _knowledgeRepository;
  StreamSubscription<PlantDiagnosis?>? _subscription;

  Future<void> _onChanged(
    DiagnosisDetailsChanged event,
    Emitter<DiagnosisDetailsState> emit,
  ) async {
    final item = event.item;
    if (item == null) {
      emit(
        const DiagnosisDetailsState(status: DiagnosisDetailsStatus.notFound),
      );
      return;
    }
    try {
      final documents = await _knowledgeRepository.loadSources(
        item.sourceIds.toSet(),
      );
      if (documents.warnings.isNotEmpty ||
          documents.items.map((source) => source.id).toSet().length !=
              item.sourceIds.toSet().length) {
        throw const FormatException('Missing source attribution.');
      }
      emit(
        DiagnosisDetailsState(
          status: DiagnosisDetailsStatus.loaded,
          item: item,
          sources: documents.items,
        ),
      );
    } catch (_) {
      emit(
        const DiagnosisDetailsState(
          status: DiagnosisDetailsStatus.failure,
          errorMessage: 'Trusted source attribution is unavailable.',
        ),
      );
    }
  }

  Future<void> _onWatch(
    DiagnosisDetailsWatchRequested event,
    Emitter<DiagnosisDetailsState> emit,
  ) async {
    await _subscription?.cancel();
    emit(const DiagnosisDetailsState(status: DiagnosisDetailsStatus.loading));
    try {
      _subscription = _repository
          .watchDiagnosis(event.plantId, event.observationId, event.diagnosisId)
          .listen(
            (item) => add(DiagnosisDetailsChanged(item)),
            onError: (Object error) => add(
              DiagnosisDetailsFailed(
                error is AppError
                    ? error.message
                    : 'Couldn\'t load this diagnosis. Try again.',
              ),
            ),
          );
    } on AppError catch (error) {
      emit(
        DiagnosisDetailsState(
          status: DiagnosisDetailsStatus.failure,
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
