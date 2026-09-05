import 'package:equatable/equatable.dart';

abstract final class KnowledgeVersions {
  static const schema = 1;
  static const dataset = '2026-09-03-v2';
  static const preferredDataset = '2026-09-05-v3';
  static const supportedDatasets = {'2026-09-03-v1', dataset, preferredDataset};
  static const diagnosisDatasets = {dataset, preferredDataset};
  static const algorithm = 'metadata-v1';
}

abstract final class KnowledgeDatasetInventory {
  static const preferredSourceCount = 19;
  static const preferredChunkCount = 60;
  static const productionChunksPerPlant = {
    'tomato': 10,
    'pumpkin': 11,
    'pothos': 10,
    'snake_plant': 10,
    'peace_lily': 9,
  };
  static const preferredChunksPerPlant = {
    'tomato': 12,
    'pumpkin': 13,
    'pothos': 12,
    'snake_plant': 12,
    'peace_lily': 11,
  };
}

final class KnowledgeChunk extends Equatable {
  const KnowledgeChunk({
    required this.id,
    required this.canonicalPlantKey,
    required this.category,
    required this.environment,
    required this.affectedParts,
    required this.growthStages,
    required this.symptomKeywords,
    required this.title,
    required this.content,
    required this.cautions,
    required this.sourceIds,
    required this.datasetVersion,
  });

  final String id;
  final String canonicalPlantKey;
  final String category;
  final List<String> environment;
  final List<String> affectedParts;
  final List<String> growthStages;
  final List<String> symptomKeywords;
  final String title;
  final String content;
  final List<String> cautions;
  final List<String> sourceIds;
  final String datasetVersion;

  @override
  List<Object?> get props => [
    id,
    canonicalPlantKey,
    category,
    environment,
    affectedParts,
    growthStages,
    symptomKeywords,
    title,
    content,
    cautions,
    sourceIds,
    datasetVersion,
  ];
}

final class KnowledgeSource extends Equatable {
  const KnowledgeSource({
    required this.id,
    required this.title,
    required this.publisher,
    required this.url,
    required this.datasetVersion,
  });

  final String id;
  final String title;
  final String publisher;
  final String url;
  final String datasetVersion;

  @override
  List<Object?> get props => [id, title, publisher, url, datasetVersion];
}

final class KnowledgeDocuments<T extends Equatable> extends Equatable {
  const KnowledgeDocuments({required this.items, this.warnings = const []});

  final List<T> items;
  final List<String> warnings;

  @override
  List<Object?> get props => [items, warnings];
}

final class KnowledgeEvidenceSet extends Equatable {
  const KnowledgeEvidenceSet({
    required this.datasetVersion,
    required this.canonicalPlantKey,
    required this.chunks,
    required this.sources,
    this.warnings = const [],
  });

  final String datasetVersion;
  final String canonicalPlantKey;
  final List<KnowledgeChunk> chunks;
  final List<KnowledgeSource> sources;
  final List<String> warnings;

  @override
  List<Object?> get props => [
    datasetVersion,
    canonicalPlantKey,
    chunks,
    sources,
    warnings,
  ];
}

final class KnowledgeDatasetCompatibilitySelector {
  const KnowledgeDatasetCompatibilitySelector();

  KnowledgeEvidenceSet select({
    required KnowledgeEvidenceSet fallback,
    KnowledgeEvidenceSet? preferred,
  }) {
    if (preferred != null &&
        _isComplete(
          preferred,
          KnowledgeVersions.preferredDataset,
          KnowledgeDatasetInventory.preferredChunksPerPlant,
        )) {
      return preferred;
    }
    if (_isComplete(
      fallback,
      KnowledgeVersions.dataset,
      KnowledgeDatasetInventory.productionChunksPerPlant,
    )) {
      return fallback;
    }
    return KnowledgeEvidenceSet(
      datasetVersion: KnowledgeVersions.dataset,
      canonicalPlantKey: fallback.canonicalPlantKey,
      chunks: const [],
      sources: const [],
      warnings: [
        ...fallback.warnings,
        'The complete production knowledge dataset is unavailable.',
      ],
    );
  }

  bool _isComplete(
    KnowledgeEvidenceSet evidence,
    String version,
    Map<String, int> expectedChunksPerPlant,
  ) {
    final expectedCount = expectedChunksPerPlant[evidence.canonicalPlantKey];
    if (expectedCount == null ||
        evidence.datasetVersion != version ||
        evidence.warnings.isNotEmpty ||
        evidence.chunks.length != expectedCount) {
      return false;
    }
    final chunkIds = evidence.chunks.map((chunk) => chunk.id).toSet();
    final sourcesById = {
      for (final source in evidence.sources) source.id: source,
    };
    if (chunkIds.length != evidence.chunks.length ||
        sourcesById.length != evidence.sources.length) {
      return false;
    }
    return evidence.chunks.every(
          (chunk) =>
              chunk.canonicalPlantKey == evidence.canonicalPlantKey &&
              chunk.datasetVersion == version &&
              chunk.sourceIds.isNotEmpty &&
              chunk.sourceIds.every(sourcesById.containsKey),
        ) &&
        evidence.sources.every((source) => source.datasetVersion == version);
  }
}

final class RankedKnowledgeMatch extends Equatable {
  const RankedKnowledgeMatch({
    required this.chunk,
    required this.score,
    required this.matchedSignals,
    this.sources = const [],
  });

  final KnowledgeChunk chunk;
  final int score;
  final List<String> matchedSignals;
  final List<KnowledgeSource> sources;

  RankedKnowledgeMatch withSources(List<KnowledgeSource> value) =>
      RankedKnowledgeMatch(
        chunk: chunk,
        score: score,
        matchedSignals: matchedSignals,
        sources: value,
      );

  @override
  List<Object?> get props => [chunk, score, matchedSignals, sources];
}

final class KnowledgeRetrievalResult extends Equatable {
  const KnowledgeRetrievalResult({
    required this.canonicalPlantKey,
    required this.datasetVersion,
    required this.algorithmVersion,
    required this.rankedMatches,
    required this.warnings,
  });

  final String canonicalPlantKey;
  final String datasetVersion;
  final String algorithmVersion;
  final List<RankedKnowledgeMatch> rankedMatches;
  final List<String> warnings;

  @override
  List<Object?> get props => [
    canonicalPlantKey,
    datasetVersion,
    algorithmVersion,
    rankedMatches,
    warnings,
  ];
}
