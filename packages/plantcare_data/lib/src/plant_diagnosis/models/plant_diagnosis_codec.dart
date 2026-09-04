import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';

abstract final class PlantDiagnosisCodec {
  static const maxIssues = 3;
  static const maxActions = 3;
  static const maxAvoidActions = 3;
  static const maxUncertainties = 5;
  static const maxSupportingObservations = 5;
  static const maxEvidenceIds = 5;
  static const maxSummaryLength = 600;
  static const maxShortTextLength = 160;
  static const maxBodyTextLength = 600;

  static PlantDiagnosis fromAiJson(
    Map<String, dynamic> json, {
    required KnowledgeRetrievalResult retrieval,
    required String modelName,
  }) {
    _requireOnly(json, const {
      'schemaVersion',
      'status',
      'summary',
      'possibleIssues',
      'recommendedActions',
      'avoidActions',
      'uncertainties',
      'followUp',
    });
    final version = _integer(json, 'schemaVersion');
    if (version != PlantDiagnosis.currentSchemaVersion) {
      throw const FormatException('Unsupported diagnosis schema.');
    }
    final allowedChunkIds = retrieval.rankedMatches
        .map((match) => match.chunk.id)
        .toSet();
    if (allowedChunkIds.isEmpty) {
      throw const FormatException('Diagnosis requires grounded evidence.');
    }
    final sourceIdsByChunk = {
      for (final match in retrieval.rankedMatches)
        match.chunk.id: match.chunk.sourceIds.toSet(),
    };
    final issues = _list(json, 'possibleIssues', maxIssues)
        .map(
          (raw) => _decodeIssue(_entry(raw, 'possibleIssues'), allowedChunkIds),
        )
        .toList(growable: false);
    final actions = _list(json, 'recommendedActions', maxActions)
        .map(
          (raw) =>
              _decodeAction(_entry(raw, 'recommendedActions'), allowedChunkIds),
        )
        .toList(growable: false);
    final avoid = _list(json, 'avoidActions', maxAvoidActions)
        .map(
          (raw) =>
              _decodeAvoidAction(_entry(raw, 'avoidActions'), allowedChunkIds),
        )
        .toList(growable: false);
    final status = _enum(json, 'status', DiagnosisStatus.values);
    if (status == DiagnosisStatus.insufficientEvidence && issues.isNotEmpty) {
      throw const FormatException(
        'Insufficient-evidence responses cannot contain possible issues.',
      );
    }
    if (status == DiagnosisStatus.healthyAppearance && issues.isNotEmpty) {
      throw const FormatException(
        'Healthy-appearance responses cannot contain possible issues.',
      );
    }
    if (status == DiagnosisStatus.possibleIssuesFound && issues.isEmpty) {
      throw const FormatException('Possible issues are required.');
    }
    final summary = _plainString(json, 'summary', maxSummaryLength);
    if (!_isCautious(summary)) {
      throw const FormatException('Diagnosis summary must be cautious.');
    }
    final followUpJson = _map(json, 'followUp');
    _requireOnly(followUpJson, const {
      'anotherPhotoHelpful',
      'instruction',
      'professionalHelpRecommended',
      'professionalHelpReason',
    });
    final usedChunkIds = <String>{
      ...issues.expand((item) => item.evidenceChunkIds),
      ...actions.expand((item) => item.evidenceChunkIds),
      ...avoid.expand((item) => item.evidenceChunkIds),
    };
    if (usedChunkIds.isEmpty) {
      usedChunkIds.addAll(allowedChunkIds);
    }
    final sourceIds =
        usedChunkIds
            .expand((id) => sourceIdsByChunk[id] ?? const <String>{})
            .toSet()
            .toList()
          ..sort();
    if (sourceIds.length > 5) {
      throw const FormatException('Too many source references.');
    }
    return PlantDiagnosis(
      schemaVersion: version,
      status: status,
      summary: summary,
      possibleIssues: issues,
      recommendedActions: actions,
      avoidActions: avoid,
      uncertainties: _stringList(
        json,
        'uncertainties',
        maxUncertainties,
        maxBodyTextLength,
      ),
      followUp: DiagnosisFollowUp(
        anotherPhotoHelpful: _boolean(followUpJson, 'anotherPhotoHelpful'),
        instruction: _nullablePlainString(
          followUpJson,
          'instruction',
          maxBodyTextLength,
        ),
        professionalHelpRecommended: _boolean(
          followUpJson,
          'professionalHelpRecommended',
        ),
        professionalHelpReason: _nullablePlainString(
          followUpJson,
          'professionalHelpReason',
          maxBodyTextLength,
        ),
      ),
      canonicalPlantKey: retrieval.canonicalPlantKey,
      evidenceChunkIds: usedChunkIds.toList()..sort(),
      sourceIds: sourceIds,
      datasetVersion: retrieval.datasetVersion,
      retrievalAlgorithmVersion: retrieval.algorithmVersion,
      modelName: modelName,
    );
  }

  static PlantDiagnosis fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) throw const FormatException('Diagnosis is missing.');
    return fromFirestoreData(id: snapshot.id, data: data);
  }

  static PlantDiagnosis fromFirestoreData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    _requireOnly(data, const {
      'schemaVersion',
      'status',
      'summary',
      'possibleIssues',
      'recommendedActions',
      'avoidActions',
      'uncertainties',
      'followUp',
      'canonicalPlantKey',
      'evidenceChunkIds',
      'sourceIds',
      'datasetVersion',
      'retrievalAlgorithmVersion',
      'modelName',
      'source',
      'createdAt',
    });
    if (data['source'] != PlantDiagnosis.source) {
      throw const FormatException('Invalid diagnosis source.');
    }
    final evidence = _idList(
      data,
      'evidenceChunkIds',
      5,
      maxShortTextLength,
    ).toSet();
    final sources = _idList(data, 'sourceIds', 5, maxShortTextLength);
    final retrieval = KnowledgeRetrievalResult(
      canonicalPlantKey: _plainString(
        data,
        'canonicalPlantKey',
        maxShortTextLength,
      ),
      datasetVersion: _plainString(data, 'datasetVersion', maxShortTextLength),
      algorithmVersion: _plainString(
        data,
        'retrievalAlgorithmVersion',
        maxShortTextLength,
      ),
      rankedMatches: evidence
          .map(
            (chunkId) => RankedKnowledgeMatch(
              chunk: KnowledgeChunk(
                id: chunkId,
                canonicalPlantKey: data['canonicalPlantKey'] as String,
                category: 'persisted',
                environment: const [],
                affectedParts: const [],
                growthStages: const [],
                symptomKeywords: const [],
                title: 'Persisted evidence',
                content: 'Persisted evidence',
                cautions: const [],
                sourceIds: sources,
                datasetVersion: data['datasetVersion'] as String,
              ),
              score: 0,
              matchedSignals: const [],
            ),
          )
          .toList(growable: false),
      warnings: const [],
    );
    final aiJson = Map<String, dynamic>.from(data)
      ..remove('canonicalPlantKey')
      ..remove('evidenceChunkIds')
      ..remove('sourceIds')
      ..remove('datasetVersion')
      ..remove('retrievalAlgorithmVersion')
      ..remove('modelName')
      ..remove('source')
      ..remove('createdAt');
    final parsed = fromAiJson(
      aiJson,
      retrieval: retrieval,
      modelName: _plainString(data, 'modelName', 80),
    );
    final timestamp = data['createdAt'];
    if (timestamp != null && timestamp is! Timestamp) {
      throw const FormatException('Invalid diagnosis timestamp.');
    }
    if (!parsed.evidenceChunkIds.toSet().containsAll(evidence) ||
        !evidence.containsAll(parsed.evidenceChunkIds)) {
      throw const FormatException('Diagnosis evidence metadata mismatch.');
    }
    return PlantDiagnosis(
      id: id,
      schemaVersion: parsed.schemaVersion,
      status: parsed.status,
      summary: parsed.summary,
      possibleIssues: parsed.possibleIssues,
      recommendedActions: parsed.recommendedActions,
      avoidActions: parsed.avoidActions,
      uncertainties: parsed.uncertainties,
      followUp: parsed.followUp,
      canonicalPlantKey: parsed.canonicalPlantKey,
      evidenceChunkIds: parsed.evidenceChunkIds,
      sourceIds: sources,
      datasetVersion: parsed.datasetVersion,
      retrievalAlgorithmVersion: parsed.retrievalAlgorithmVersion,
      modelName: parsed.modelName,
      createdAt: (timestamp as Timestamp?)?.toDate(),
    );
  }

  static Map<String, Object?> toFirestore(PlantDiagnosis value) => {
    ...toStructuredJson(value),
    'canonicalPlantKey': value.canonicalPlantKey,
    'evidenceChunkIds': value.evidenceChunkIds,
    'sourceIds': value.sourceIds,
    'datasetVersion': value.datasetVersion,
    'retrievalAlgorithmVersion': value.retrievalAlgorithmVersion,
    'modelName': value.modelName,
    'source': PlantDiagnosis.source,
    'createdAt': FieldValue.serverTimestamp(),
  };

  static Map<String, Object?> toStructuredJson(PlantDiagnosis value) => {
    'schemaVersion': value.schemaVersion,
    'status': _snake(value.status.name),
    'summary': value.summary,
    'possibleIssues': value.possibleIssues
        .map(
          (item) => {
            'name': item.name,
            'likelihood': _snake(item.likelihood.name),
            'evidenceStrength': _snake(item.evidenceStrength.name),
            'supportingObservations': item.supportingObservations,
            'reasoning': item.reasoning,
            'evidenceChunkIds': item.evidenceChunkIds,
          },
        )
        .toList(growable: false),
    'recommendedActions': value.recommendedActions
        .map(
          (item) => {
            'action': item.action,
            'priority': _snake(item.priority.name),
            'reason': item.reason,
            'evidenceChunkIds': item.evidenceChunkIds,
          },
        )
        .toList(growable: false),
    'avoidActions': value.avoidActions
        .map(
          (item) => {
            'action': item.action,
            'reason': item.reason,
            'evidenceChunkIds': item.evidenceChunkIds,
          },
        )
        .toList(growable: false),
    'uncertainties': value.uncertainties,
    'followUp': {
      'anotherPhotoHelpful': value.followUp.anotherPhotoHelpful,
      'instruction': value.followUp.instruction,
      'professionalHelpRecommended': value.followUp.professionalHelpRecommended,
      'professionalHelpReason': value.followUp.professionalHelpReason,
    },
  };

  static DiagnosisIssue _decodeIssue(
    Map<String, dynamic> map,
    Set<String> allowed,
  ) {
    _requireOnly(map, const {
      'name',
      'likelihood',
      'evidenceStrength',
      'supportingObservations',
      'reasoning',
      'evidenceChunkIds',
    });
    final reasoning = _plainString(map, 'reasoning', maxBodyTextLength);
    if (!_isCautious(reasoning)) {
      throw const FormatException('Issue reasoning must be cautious.');
    }
    return DiagnosisIssue(
      name: _plainString(map, 'name', maxShortTextLength),
      likelihood: _enum(map, 'likelihood', DiagnosisLikelihood.values),
      evidenceStrength: _enum(
        map,
        'evidenceStrength',
        DiagnosisEvidenceStrength.values,
      ),
      supportingObservations: _stringList(
        map,
        'supportingObservations',
        maxSupportingObservations,
        maxBodyTextLength,
      ),
      reasoning: reasoning,
      evidenceChunkIds: _evidenceIds(map, allowed),
    );
  }

  static DiagnosisAction _decodeAction(
    Map<String, dynamic> map,
    Set<String> allowed,
  ) {
    _requireOnly(map, const {
      'action',
      'priority',
      'reason',
      'evidenceChunkIds',
    });
    return DiagnosisAction(
      action: _plainString(map, 'action', maxBodyTextLength),
      priority: _enum(map, 'priority', DiagnosisActionPriority.values),
      reason: _plainString(map, 'reason', maxBodyTextLength),
      evidenceChunkIds: _evidenceIds(map, allowed),
    );
  }

  static DiagnosisAvoidAction _decodeAvoidAction(
    Map<String, dynamic> map,
    Set<String> allowed,
  ) {
    _requireOnly(map, const {'action', 'reason', 'evidenceChunkIds'});
    return DiagnosisAvoidAction(
      action: _plainString(map, 'action', maxBodyTextLength),
      reason: _plainString(map, 'reason', maxBodyTextLength),
      evidenceChunkIds: _evidenceIds(map, allowed),
    );
  }

  static List<String> _evidenceIds(
    Map<String, dynamic> map,
    Set<String> allowed,
  ) {
    final ids = _idList(
      map,
      'evidenceChunkIds',
      maxEvidenceIds,
      maxShortTextLength,
    );
    if (ids.isEmpty || ids.any((id) => !allowed.contains(id))) {
      throw const FormatException('Unknown evidence reference.');
    }
    return ids;
  }

  static bool _isCautious(String value) {
    final normalized = value.toLowerCase();
    return const [
      'may',
      'might',
      'could',
      'appears',
      'appearance',
      'consistent with',
      'suggests',
      'uncertain',
      'not enough',
      'insufficient',
      'cannot confirm',
    ].any(normalized.contains);
  }

  static void _requireOnly(Map<String, dynamic> map, Set<String> keys) {
    final actual = map.keys.toSet();
    if (!actual.containsAll(keys) || actual.difference(keys).isNotEmpty) {
      throw const FormatException('Diagnosis fields do not match schema.');
    }
  }

  static Map<String, dynamic> _map(Map<String, dynamic> map, String key) =>
      _entry(map[key], key);

  static Map<String, dynamic> _entry(Object? value, String key) {
    if (value is! Map) throw FormatException('$key must be an object.');
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(
    Map<String, dynamic> map,
    String key,
    int maxLength,
  ) {
    final value = map[key];
    if (value is! List || value.length > maxLength) {
      throw FormatException('$key must be a bounded array.');
    }
    return value;
  }

  static List<String> _stringList(
    Map<String, dynamic> map,
    String key,
    int maxLength,
    int maxStringLength,
  ) => _list(map, key, maxLength)
      .map((value) => _plainValue(value, key, maxStringLength))
      .toList(growable: false);

  static List<String> _idList(
    Map<String, dynamic> map,
    String key,
    int maxLength,
    int maxStringLength,
  ) => _list(map, key, maxLength)
      .map((value) {
        if (value is! String ||
            value.length > maxStringLength ||
            !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]*$').hasMatch(value)) {
          throw FormatException('$key must contain valid IDs.');
        }
        return value;
      })
      .toList(growable: false);

  static String _plainString(
    Map<String, dynamic> map,
    String key,
    int maxLength,
  ) => _plainValue(map[key], key, maxLength);

  static String _plainValue(Object? value, String key, int maxLength) {
    if (value is! String ||
        value.isEmpty ||
        value != value.trim() ||
        value.length > maxLength ||
        RegExp(r'<[^>]*>|https?://|\[[^\]]+\]\([^\)]+\)|[`*_#]')
            .hasMatch(value)) {
      throw FormatException('$key must be bounded plain text.');
    }
    return value;
  }

  static String? _nullablePlainString(
    Map<String, dynamic> map,
    String key,
    int maxLength,
  ) => map[key] == null ? null : _plainString(map, key, maxLength);

  static bool _boolean(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) throw FormatException('$key must be a boolean.');
    return value;
  }

  static int _integer(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static T _enum<T extends Enum>(
    Map<String, dynamic> map,
    String key,
    List<T> values,
  ) {
    final raw = map[key];
    if (raw is! String) throw FormatException('$key must be an enum.');
    return values.firstWhere(
      (value) => _snake(value.name) == raw,
      orElse: () => throw FormatException('Unsupported $key value.'),
    );
  }

  static String _snake(String value) => value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .toLowerCase();
}
