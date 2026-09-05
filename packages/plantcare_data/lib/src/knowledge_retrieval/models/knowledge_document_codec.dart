import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';

abstract final class KnowledgeDocumentCodec {
  static const _categories = {
    'identity',
    'basic_care',
    'watering',
    'soil',
    'sunlight',
    'temperature',
    'humidity',
    'nutrient_guidance',
    'nutrient_deficiency',
    'fungal_disease',
    'bacterial_disease',
    'viral_disease',
    'pests',
    'overwatering',
    'underwatering',
    'heat_stress',
    'cold_stress',
    'toxicity',
    'prevention',
  };
  static const _environments = {'indoor', 'outdoor'};
  static const _parts = {
    'leaf',
    'stem',
    'flower',
    'fruit',
    'root',
    'whole_plant',
    'unknown',
  };
  static const _stages = {
    'seedling',
    'vegetative',
    'flowering',
    'fruiting',
    'mature',
  };

  static KnowledgeChunk chunk(String id, Map<String, dynamic> data) {
    _requireKeys(
      data,
      const {
        'schemaVersion',
        'canonicalPlantKey',
        'commonName',
        'scientificName',
        'aliases',
        'category',
        'environment',
        'affectedParts',
        'growthStages',
        'symptomKeywords',
        'title',
        'content',
        'cautions',
        'sourceIds',
        'reviewStatus',
        'datasetVersion',
        'createdAt',
        'updatedAt',
      },
      optional: const {'issueKey'},
    );
    _version(data);
    final dataset = _dataset(data);
    final canonicalKey = _text(data, 'canonicalPlantKey', 40);
    if (!const {
      'tomato',
      'pumpkin',
      'pothos',
      'snake_plant',
      'peace_lily',
    }.contains(canonicalKey)) {
      throw const FormatException('Unsupported canonical plant key.');
    }
    final category = _text(data, 'category', 40);
    if (!_categories.contains(category)) {
      throw const FormatException('Unsupported knowledge category.');
    }
    if (data['reviewStatus'] != 'reviewed') {
      throw const FormatException('Knowledge chunk is not reviewed.');
    }
    _text(data, 'commonName', 80);
    _text(data, 'scientificName', 120);
    _strings(data, 'aliases', 12, 120);
    final issueKey = data['issueKey'];
    if (issueKey != null && !_snakeCase(_text(data, 'issueKey', 100))) {
      throw const FormatException('Invalid issueKey.');
    }
    _timestamp(data, 'createdAt');
    _timestamp(data, 'updatedAt');
    final symptoms = _strings(data, 'symptomKeywords', 15, 80);
    final sourceIds = _strings(data, 'sourceIds', 5, 100, minimum: 1);
    if (!symptoms.every(_snakeCase) || !sourceIds.every(_snakeCase)) {
      throw const FormatException('Invalid normalized knowledge key.');
    }
    return KnowledgeChunk(
      id: _validId(id),
      canonicalPlantKey: canonicalKey,
      category: category,
      environment: _enumList(data, 'environment', _environments, 2),
      affectedParts: _enumList(data, 'affectedParts', _parts, 7),
      growthStages: _enumList(data, 'growthStages', _stages, 5),
      symptomKeywords: symptoms,
      title: _text(data, 'title', 140),
      content: _text(data, 'content', 900, minimum: 100),
      cautions: _strings(data, 'cautions', 8, 300),
      sourceIds: sourceIds,
      datasetVersion: dataset,
    );
  }

  static KnowledgeDocuments<KnowledgeChunk> chunks(
    Map<String, Map<String, dynamic>> documents,
  ) {
    final items = <KnowledgeChunk>[];
    final warnings = <String>[];
    for (final entry in documents.entries) {
      try {
        items.add(chunk(entry.key, entry.value));
      } on FormatException {
        warnings.add('Excluded invalid knowledge chunk ${entry.key}.');
      }
    }
    return KnowledgeDocuments(items: items, warnings: warnings);
  }

  static KnowledgeSource source(String id, Map<String, dynamic> data) {
    _requireKeys(data, const {
      'schemaVersion',
      'title',
      'publisher',
      'url',
      'accessedAt',
      'sourceType',
      'datasetVersion',
    });
    _version(data);
    final url = _text(data, 'url', 2000);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Source URL must be a valid HTTPS URL.');
    }
    _timestamp(data, 'accessedAt');
    if (!const {
      'government',
      'university_extension',
      'botanical_garden',
      'peer_reviewed',
      'institutional_horticulture',
    }.contains(data['sourceType'])) {
      throw const FormatException('Unsupported source type.');
    }
    return KnowledgeSource(
      id: _validId(id),
      title: _text(data, 'title', 240),
      publisher: _text(data, 'publisher', 160),
      url: uri.toString(),
      datasetVersion: _dataset(data),
    );
  }

  static KnowledgeDocuments<KnowledgeSource> sources(
    Map<String, Map<String, dynamic>?> documents,
  ) {
    final items = <KnowledgeSource>[];
    final warnings = <String>[];
    for (final entry in documents.entries) {
      final data = entry.value;
      if (data == null) {
        warnings.add('Source ${entry.key} is currently unavailable.');
        continue;
      }
      try {
        items.add(source(entry.key, data));
      } on FormatException {
        warnings.add('Excluded invalid source ${entry.key}.');
      }
    }
    return KnowledgeDocuments(items: items, warnings: warnings);
  }

  static bool isCompletePreferredRelease(Map<String, dynamic> data) {
    const required = {
      'schemaVersion',
      'datasetVersion',
      'status',
      'expectedSourceCount',
      'expectedChunkCount',
      'chunksPerPlant',
      'verifiedAt',
    };
    if (data.keys.toSet().difference(required).isNotEmpty ||
        !data.keys.toSet().containsAll(required) ||
        data['schemaVersion'] != KnowledgeVersions.schema ||
        data['datasetVersion'] != KnowledgeVersions.preferredDataset ||
        data['status'] != 'complete' ||
        data['expectedSourceCount'] !=
            KnowledgeDatasetInventory.preferredSourceCount ||
        data['expectedChunkCount'] !=
            KnowledgeDatasetInventory.preferredChunkCount ||
        data['verifiedAt'] is! Timestamp) {
      return false;
    }
    final counts = data['chunksPerPlant'];
    if (counts is! Map<String, dynamic> ||
        counts.keys
            .toSet()
            .difference(
              KnowledgeDatasetInventory.preferredChunksPerPlant.keys.toSet(),
            )
            .isNotEmpty ||
        !counts.keys.toSet().containsAll(
          KnowledgeDatasetInventory.preferredChunksPerPlant.keys,
        )) {
      return false;
    }
    return KnowledgeDatasetInventory.preferredChunksPerPlant.entries.every(
      (entry) => counts[entry.key] == entry.value,
    );
  }

  static void _version(Map<String, dynamic> data) {
    if (data['schemaVersion'] != KnowledgeVersions.schema) {
      throw const FormatException('Unsupported knowledge schema version.');
    }
  }

  static void _requireKeys(
    Map<String, dynamic> data,
    Set<String> required, {
    Set<String> optional = const {},
  }) {
    final keys = data.keys.toSet();
    if (!keys.containsAll(required) ||
        keys.difference({...required, ...optional}).isNotEmpty) {
      throw const FormatException('Knowledge fields do not match schema.');
    }
  }

  static bool _snakeCase(String value) =>
      RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(value);

  static void _timestamp(Map<String, dynamic> data, String key) {
    if (data[key] is! Timestamp) throw FormatException('Invalid $key.');
  }

  static String _dataset(Map<String, dynamic> data) {
    final value = data['datasetVersion'];
    if (value is! String ||
        !KnowledgeVersions.supportedDatasets.contains(value)) {
      throw const FormatException('Unsupported knowledge dataset version.');
    }
    return value;
  }

  static String _validId(String id) {
    if (id.trim().isEmpty || id.contains('/')) {
      throw const FormatException('Invalid knowledge document ID.');
    }
    return id;
  }

  static String _text(
    Map<String, dynamic> data,
    String key,
    int maximum, {
    int minimum = 1,
  }) {
    final value = data[key];
    if (value is! String ||
        value != value.trim() ||
        value.length < minimum ||
        value.length > maximum) {
      throw FormatException('Invalid $key.');
    }
    return value;
  }

  static List<String> _strings(
    Map<String, dynamic> data,
    String key,
    int maximumItems,
    int maximumLength, {
    int minimum = 0,
  }) {
    final value = data[key];
    if (value is! List ||
        value.length < minimum ||
        value.length > maximumItems) {
      throw FormatException('Invalid $key.');
    }
    final result = value
        .map((item) {
          if (item is! String ||
              item != item.trim() ||
              item.isEmpty ||
              item.length > maximumLength) {
            throw FormatException('Invalid $key item.');
          }
          return item;
        })
        .toList(growable: false);
    if (result.toSet().length != result.length) {
      throw FormatException('$key must be unique.');
    }
    return result;
  }

  static List<String> _enumList(
    Map<String, dynamic> data,
    String key,
    Set<String> allowed,
    int maximumItems,
  ) {
    final values = _strings(data, key, maximumItems, 40, minimum: 1);
    if (!values.every(allowed.contains)) {
      throw FormatException('Unsupported $key value.');
    }
    return values;
  }
}
