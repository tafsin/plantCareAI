import '../entities/knowledge_retrieval.dart';

abstract interface class KnowledgeRepository {
  Future<KnowledgeDocuments<KnowledgeChunk>> loadChunksForPlant(
    String canonicalPlantKey,
  );

  Future<KnowledgeDocuments<KnowledgeSource>> loadSources(Set<String> ids);
}
