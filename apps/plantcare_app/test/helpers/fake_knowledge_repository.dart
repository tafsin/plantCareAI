import 'dart:async';

import 'package:plantcare_domain/knowledge_retrieval.dart';

const sampleKnowledgeChunk = KnowledgeChunk(
  id: 'tomato__fungal_disease__yellow_leaf',
  canonicalPlantKey: 'tomato',
  category: 'fungal_disease',
  environment: ['outdoor'],
  affectedParts: ['leaf'],
  growthStages: ['mature'],
  symptomKeywords: ['yellowing'],
  title: 'Yellow leaf reference',
  content: 'Yellowing on tomato leaves can have several overlapping causes. Compare the visible pattern, affected plant parts, growing conditions, and symptom progression before deciding what might be responsible.',
  cautions: ['A photograph alone cannot confirm a diagnosis.'],
  sourceIds: ['extension_source'],
  datasetVersion: KnowledgeVersions.dataset,
);

const sampleKnowledgeSource = KnowledgeSource(
  id: 'extension_source',
  title: 'Tomato problems',
  publisher: 'University Extension',
  url: 'https://example.edu/tomato',
  datasetVersion: KnowledgeVersions.dataset,
);

final class FakeKnowledgeRepository implements KnowledgeRepository {
  KnowledgeDocuments<KnowledgeChunk> chunks = const KnowledgeDocuments(
    items: [sampleKnowledgeChunk],
  );
  KnowledgeDocuments<KnowledgeSource> sources = const KnowledgeDocuments(
    items: [sampleKnowledgeSource],
  );
  Object? chunkError;
  Object? sourceError;
  Completer<KnowledgeDocuments<KnowledgeChunk>>? chunkCompleter;
  int chunkCalls = 0;
  int sourceCalls = 0;
  String? requestedPlantKey;
  Set<String>? requestedSourceIds;

  @override
  Future<KnowledgeEvidenceSet> loadPreferredEvidenceForPlant(
    String canonicalPlantKey,
  ) async {
    final loadedChunks = await loadChunksForPlant(canonicalPlantKey);
    final ids = loadedChunks.items.expand((chunk) => chunk.sourceIds).toSet();
    final loadedSources = ids.isEmpty
        ? const KnowledgeDocuments<KnowledgeSource>(items: [])
        : await loadSources(ids);
    return KnowledgeEvidenceSet(
      datasetVersion: loadedChunks.items.isEmpty
          ? KnowledgeVersions.dataset
          : loadedChunks.items.first.datasetVersion,
      canonicalPlantKey: canonicalPlantKey,
      chunks: loadedChunks.items,
      sources: loadedSources.items,
      warnings: [...loadedChunks.warnings, ...loadedSources.warnings],
    );
  }

  @override
  Future<KnowledgeDocuments<KnowledgeChunk>> loadChunksForPlant(
    String canonicalPlantKey,
  ) {
    chunkCalls++;
    requestedPlantKey = canonicalPlantKey;
    if (chunkError case final Object error) return Future.error(error);
    return chunkCompleter?.future ?? Future.value(chunks);
  }

  @override
  Future<KnowledgeDocuments<KnowledgeSource>> loadSources(Set<String> ids) {
    sourceCalls++;
    requestedSourceIds = ids;
    if (sourceError case final Object error) return Future.error(error);
    return Future.value(sources);
  }
}
