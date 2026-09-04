import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';

final class ValidatedSoilEvidence {
  const ValidatedSoilEvidence({required this.chunks, required this.sources});
  final List<KnowledgeChunk> chunks;
  final List<KnowledgeSource> sources;
}

final class SoilEvidenceValidator {
  const SoilEvidenceValidator(this._repository);
  final KnowledgeRepository _repository;

  Future<ValidatedSoilEvidence> validate(
    String canonicalPlantKey,
    List<String> requiredChunkIds,
  ) async {
    final documents = await _repository.loadChunksForPlant(canonicalPlantKey);
    final byId = {for (final chunk in documents.items) chunk.id: chunk};
    if (documents.warnings.isNotEmpty ||
        !byId.keys.toSet().containsAll(requiredChunkIds)) {
      throw const SoilCheckFailure(
        SoilCheckFailureType.insufficientEvidence,
        'Required watering evidence is missing or malformed. The result was not saved.',
      );
    }
    final chunks = requiredChunkIds
        .map((id) => byId[id]!)
        .toList(growable: false);
    if (chunks.any(
      (chunk) =>
          chunk.canonicalPlantKey != canonicalPlantKey ||
          chunk.datasetVersion != KnowledgeVersions.dataset ||
          chunk.sourceIds.isEmpty,
    )) {
      throw const SoilCheckFailure(
        SoilCheckFailureType.malformedEvidence,
        'Watering evidence does not match this plant or dataset.',
      );
    }
    final sourceIds = chunks.expand((chunk) => chunk.sourceIds).toSet();
    final sourceDocuments = await _repository.loadSources(sourceIds);
    final sourceById = {
      for (final source in sourceDocuments.items) source.id: source,
    };
    if (sourceDocuments.warnings.isNotEmpty ||
        !sourceById.keys.toSet().containsAll(sourceIds) ||
        sourceById.values.any(
          (source) => source.datasetVersion != KnowledgeVersions.dataset,
        )) {
      throw const SoilCheckFailure(
        SoilCheckFailureType.malformedEvidence,
        'One or more trusted watering sources are missing or malformed.',
      );
    }
    return ValidatedSoilEvidence(
      chunks: chunks,
      sources: sourceIds.map((id) => sourceById[id]!).toList(growable: false),
    );
  }
}
