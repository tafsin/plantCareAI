import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/knowledge_ranker.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_shared/errors.dart';

sealed class KnowledgeRetrievalEvent extends Equatable {
  const KnowledgeRetrievalEvent();

  @override
  List<Object?> get props => [];
}

final class KnowledgeRetrievalRequested extends KnowledgeRetrievalEvent {
  const KnowledgeRetrievalRequested({
    required this.plant,
    required this.observation,
  });

  final Plant plant;
  final PlantObservation observation;

  @override
  List<Object?> get props => [plant, observation];
}

final class KnowledgePlantCandidateSelected extends KnowledgeRetrievalEvent {
  const KnowledgePlantCandidateSelected(this.canonicalPlantKey);

  final String canonicalPlantKey;

  @override
  List<Object?> get props => [canonicalPlantKey];
}

final class KnowledgeRetrievalRetryRequested extends KnowledgeRetrievalEvent {
  const KnowledgeRetrievalRetryRequested();
}

enum KnowledgeRetrievalStatus {
  initial,
  loading,
  unsupportedPlant,
  candidateConflict,
  noStrongMatch,
  loaded,
  failure,
}

final class KnowledgeRetrievalState extends Equatable {
  const KnowledgeRetrievalState({
    this.status = KnowledgeRetrievalStatus.initial,
    this.candidates = const [],
    this.result,
    this.errorMessage,
  });

  final KnowledgeRetrievalStatus status;
  final List<String> candidates;
  final KnowledgeRetrievalResult? result;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, candidates, result, errorMessage];
}

final class KnowledgeRetrievalBloc
    extends Bloc<KnowledgeRetrievalEvent, KnowledgeRetrievalState> {
  KnowledgeRetrievalBloc(this._repository, this._resolver, this._ranker)
    : super(const KnowledgeRetrievalState()) {
    on<KnowledgeRetrievalRequested>(_onRequested);
    on<KnowledgePlantCandidateSelected>(_onCandidateSelected);
    on<KnowledgeRetrievalRetryRequested>(_onRetry);
  }

  final KnowledgeRepository _repository;
  final PlantNameResolver _resolver;
  final KnowledgeRanker _ranker;
  KnowledgeRetrievalRequested? _lastRequest;
  String? _selectedKey;
  bool _inFlight = false;

  Future<void> _onRequested(
    KnowledgeRetrievalRequested event,
    Emitter<KnowledgeRetrievalState> emit,
  ) async {
    if (_inFlight) return;
    _lastRequest = event;
    final resolution = _resolver.resolve(event.plant, event.observation);
    switch (resolution.status) {
      case PlantResolutionStatus.unsupported:
        emit(
          const KnowledgeRetrievalState(
            status: KnowledgeRetrievalStatus.unsupportedPlant,
          ),
        );
      case PlantResolutionStatus.conflict:
        emit(
          KnowledgeRetrievalState(
            status: KnowledgeRetrievalStatus.candidateConflict,
            candidates: resolution.candidates!,
          ),
        );
      case PlantResolutionStatus.resolved:
        await _retrieve(resolution.canonicalKey!, event, emit);
    }
  }

  Future<void> _onCandidateSelected(
    KnowledgePlantCandidateSelected event,
    Emitter<KnowledgeRetrievalState> emit,
  ) async {
    final request = _lastRequest;
    if (_inFlight ||
        request == null ||
        !state.candidates.contains(event.canonicalPlantKey)) {
      return;
    }
    await _retrieve(event.canonicalPlantKey, request, emit);
  }

  Future<void> _onRetry(
    KnowledgeRetrievalRetryRequested event,
    Emitter<KnowledgeRetrievalState> emit,
  ) async {
    final request = _lastRequest;
    if (_inFlight || request == null) return;
    final selectedKey = _selectedKey;
    if (selectedKey != null) {
      await _retrieve(selectedKey, request, emit);
    } else {
      await _onRequested(request, emit);
    }
  }

  Future<void> _retrieve(
    String canonicalKey,
    KnowledgeRetrievalRequested request,
    Emitter<KnowledgeRetrievalState> emit,
  ) async {
    _inFlight = true;
    _selectedKey = canonicalKey;
    emit(
      const KnowledgeRetrievalState(status: KnowledgeRetrievalStatus.loading),
    );
    try {
      final documents = await _repository.loadChunksForPlant(canonicalKey);
      final ranked = _ranker.rank(
        canonicalPlantKey: canonicalKey,
        plant: request.plant,
        observation: request.observation,
        chunks: documents.items,
      );
      final sourceIds = ranked.expand((match) => match.chunk.sourceIds).toSet();
      final sourceDocuments = sourceIds.isEmpty
          ? const KnowledgeDocuments<KnowledgeSource>(items: [])
          : await _repository.loadSources(sourceIds);
      final sourceById = {
        for (final source in sourceDocuments.items) source.id: source,
      };
      final warnings = [...documents.warnings, ...sourceDocuments.warnings];
      final matches = ranked
          .map((match) {
            final sources = match.chunk.sourceIds
                .map((id) => sourceById[id])
                .whereType<KnowledgeSource>()
                .toList(growable: false);
            final missing = match.chunk.sourceIds.where(
              (id) => !sourceById.containsKey(id),
            );
            for (final id in missing) {
              final warning = 'Source $id is currently unavailable.';
              if (!warnings.contains(warning)) warnings.add(warning);
            }
            return match.withSources(sources);
          })
          .toList(growable: false);
      final result = KnowledgeRetrievalResult(
        canonicalPlantKey: canonicalKey,
        datasetVersion: KnowledgeVersions.dataset,
        algorithmVersion: KnowledgeVersions.algorithm,
        rankedMatches: matches,
        warnings: warnings,
      );
      emit(
        KnowledgeRetrievalState(
          status: matches.isEmpty
              ? KnowledgeRetrievalStatus.noStrongMatch
              : KnowledgeRetrievalStatus.loaded,
          result: result,
        ),
      );
    } on AppError catch (error) {
      emit(
        KnowledgeRetrievalState(
          status: KnowledgeRetrievalStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        const KnowledgeRetrievalState(
          status: KnowledgeRetrievalStatus.failure,
          errorMessage: 'Couldn\'t retrieve plant-care knowledge. Try again.',
        ),
      );
    } finally {
      _inFlight = false;
    }
  }
}
