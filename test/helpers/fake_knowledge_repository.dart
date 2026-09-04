import 'dart:async';

import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';

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
