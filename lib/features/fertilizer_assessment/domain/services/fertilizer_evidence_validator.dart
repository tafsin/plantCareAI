import 'package:plantcare_ai/features/fertilizer_assessment/domain/entities/fertilizer_assessment.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/errors/fertilizer_assessment_failure.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';

final class ValidatedFertilizerEvidence {
  const ValidatedFertilizerEvidence({
    required this.chunks,
    required this.sources,
  });
  final List<KnowledgeChunk> chunks;
  final List<KnowledgeSource> sources;
}

final class FertilizerEvidenceValidator {
  const FertilizerEvidenceValidator(this._repository);
  final KnowledgeRepository _repository;

  Future<ValidatedFertilizerEvidence> validate(
    String canonicalPlantKey,
    List<String> requiredChunkIds,
  ) async {
    final documents = await _repository.loadChunksForPlant(canonicalPlantKey);
    final byId = {for (final chunk in documents.items) chunk.id: chunk};
    if (documents.warnings.isNotEmpty ||
        requiredChunkIds.isEmpty ||
        !byId.keys.toSet().containsAll(requiredChunkIds)) {
      throw const FertilizerAssessmentFailure(
        FertilizerAssessmentFailureType.insufficientEvidence,
        'Required fertilizer evidence is missing or malformed. The result was not saved.',
      );
    }
    final chunks = requiredChunkIds
        .map((id) => byId[id]!)
        .toList(growable: false);
    if (chunks.any(
      (chunk) =>
          chunk.canonicalPlantKey != canonicalPlantKey ||
          chunk.category != 'nutrient_guidance' ||
          chunk.datasetVersion != FertilizerAssessmentVersions.dataset ||
          chunk.sourceIds.isEmpty,
    )) {
      throw const FertilizerAssessmentFailure(
        FertilizerAssessmentFailureType.malformedEvidence,
        'Fertilizer evidence does not match this plant or dataset.',
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
          (source) =>
              source.datasetVersion != FertilizerAssessmentVersions.dataset,
        )) {
      throw const FertilizerAssessmentFailure(
        FertilizerAssessmentFailureType.malformedEvidence,
        'One or more trusted fertilizer sources are missing or malformed.',
      );
    }
    return ValidatedFertilizerEvidence(
      chunks: chunks,
      sources: sourceIds.map((id) => sourceById[id]!).toList(growable: false),
    );
  }
}
