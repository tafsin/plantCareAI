import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:test/test.dart';

void main() {
  const selector = KnowledgeDatasetCompatibilitySelector();

  test('v2-only production selects the complete v2 evidence set', () {
    final v2 = _evidence(
      version: KnowledgeVersions.dataset,
      count: KnowledgeDatasetInventory.productionChunksPerPlant['tomato']!,
    );
    expect(selector.select(fallback: v2), same(v2));
  });

  test('complete v3 production is preferred atomically', () {
    final v2 = _completeV2();
    final v3 = _completeV3();
    expect(selector.select(fallback: v2, preferred: v3), same(v3));
  });

  test('partial or malformed v3 deterministically falls back to v2', () {
    final v2 = _completeV2();
    final partial = _evidence(
      version: KnowledgeVersions.preferredDataset,
      count: KnowledgeDatasetInventory.preferredChunksPerPlant['tomato']! - 1,
    );
    final malformed = _evidence(
      version: KnowledgeVersions.preferredDataset,
      count: KnowledgeDatasetInventory.preferredChunksPerPlant['tomato']!,
      warnings: const ['Excluded invalid knowledge chunk malformed.'],
    );
    expect(selector.select(fallback: v2, preferred: partial), same(v2));
    expect(selector.select(fallback: v2, preferred: malformed), same(v2));
  });

  test('mixed-version chunks or sources never become selected evidence', () {
    final v2 = _completeV2();
    final mixedChunk = _completeV3(chunkVersion: KnowledgeVersions.dataset);
    final mixedSource = _completeV3(sourceVersion: KnowledgeVersions.dataset);
    expect(selector.select(fallback: v2, preferred: mixedChunk), same(v2));
    expect(selector.select(fallback: v2, preferred: mixedSource), same(v2));
  });

  test('incomplete fallback returns no usable partial evidence', () {
    final partialV2 = _evidence(version: KnowledgeVersions.dataset, count: 1);
    final selected = selector.select(fallback: partialV2);
    expect(selected.datasetVersion, KnowledgeVersions.dataset);
    expect(selected.chunks, isEmpty);
    expect(selected.sources, isEmpty);
    expect(selected.warnings, isNotEmpty);
  });
}

KnowledgeEvidenceSet _completeV2() => _evidence(
  version: KnowledgeVersions.dataset,
  count: KnowledgeDatasetInventory.productionChunksPerPlant['tomato']!,
);

KnowledgeEvidenceSet _completeV3({
  String? chunkVersion,
  String? sourceVersion,
}) => _evidence(
  version: KnowledgeVersions.preferredDataset,
  count: KnowledgeDatasetInventory.preferredChunksPerPlant['tomato']!,
  chunkVersion: chunkVersion,
  sourceVersion: sourceVersion,
);

KnowledgeEvidenceSet _evidence({
  required String version,
  required int count,
  String? chunkVersion,
  String? sourceVersion,
  List<String> warnings = const [],
}) {
  final source = KnowledgeSource(
    id: 'extension_source',
    title: 'Trusted source',
    publisher: 'University Extension',
    url: 'https://example.edu',
    datasetVersion: sourceVersion ?? version,
  );
  return KnowledgeEvidenceSet(
    datasetVersion: version,
    canonicalPlantKey: 'tomato',
    chunks: List.generate(
      count,
      (index) => KnowledgeChunk(
        id: 'tomato__category__issue_$index',
        canonicalPlantKey: 'tomato',
        category: 'basic_care',
        environment: const ['outdoor'],
        affectedParts: const ['whole_plant'],
        growthStages: const ['mature'],
        symptomKeywords: const [],
        title: 'Evidence $index',
        content: 'Reviewed content for deterministic compatibility testing.',
        cautions: const [],
        sourceIds: const ['extension_source'],
        datasetVersion: chunkVersion ?? version,
      ),
      growable: false,
    ),
    sources: [source],
    warnings: warnings,
  );
}
