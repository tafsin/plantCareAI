import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';

abstract final class PlantObservationCodec {
  static const int maxIssues = 8;
  static const int maxAffectedParts = 8;
  static const int maxObservations = 4;

  static PlantObservation fromAiJson(Map<String, dynamic> json) {
    _requireOnly(json, const {
      'schemaVersion',
      'plantVisible',
      'imageQuality',
      'possibleIdentification',
      'affectedParts',
      'observations',
      'distribution',
      'severity',
      'followUp',
    });
    final version = _integer(json, 'schemaVersion');
    if (version != PlantObservation.currentSchemaVersion) {
      throw const FormatException('Unsupported observation schema.');
    }
    final quality = _map(json, 'imageQuality');
    _requireOnly(quality, const {'usable', 'issues'});
    final identification = _map(json, 'possibleIdentification');
    _requireOnly(identification, const {
      'commonName',
      'scientificName',
      'confidence',
    });
    final followUp = _map(json, 'followUp');
    _requireOnly(followUp, const {'anotherPhotoHelpful', 'instruction'});

    return PlantObservation(
      schemaVersion: version,
      plantVisible: _boolean(json, 'plantVisible'),
      imageQuality: ImageQuality(
        usable: _boolean(quality, 'usable'),
        issues: _enumList(
          quality,
          'issues',
          ObservationIssue.values,
          maxIssues,
        ),
      ),
      possibleIdentification: PossiblePlantIdentification(
        commonName: _optionalString(identification, 'commonName', 80),
        scientificName: _optionalString(identification, 'scientificName', 120),
        confidence: _optionalConfidence(identification, 'confidence'),
      ),
      affectedParts: _enumList(
        json,
        'affectedParts',
        AffectedPlantPart.values,
        maxAffectedParts,
      ),
      observations: _list(json, 'observations', maxObservations)
          .map((value) {
            if (value is! Map) {
              throw const FormatException('Invalid observation entry.');
            }
            final item = Map<String, dynamic>.from(value);
            _requireOnly(item, const {'type', 'description', 'confidence'});
            return VisibleObservation(
              type: _enum(item, 'type', VisualObservationType.values),
              description: _string(item, 'description', 500),
              confidence: _confidence(item, 'confidence'),
            );
          })
          .toList(growable: false),
      distribution: _string(json, 'distribution', 500, allowEmpty: true),
      severity: _enum(json, 'severity', ObservationSeverity.values),
      followUp: ObservationFollowUp(
        anotherPhotoHelpful: _boolean(followUp, 'anotherPhotoHelpful'),
        instruction: _optionalString(followUp, 'instruction', 500),
      ),
    );
  }

  static PlantObservation fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Observation document is missing.');
    }
    return fromFirestoreData(id: snapshot.id, data: data);
  }

  static PlantObservation fromFirestoreData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final nested = <String, dynamic>{
      'schemaVersion': data['schemaVersion'],
      'plantVisible': data['plantVisible'],
      'imageQuality': {
        'usable': data['imageQualityUsable'],
        'issues': data['imageQualityIssues'],
      },
      'possibleIdentification': {
        'commonName': data['possibleCommonName'],
        'scientificName': data['possibleScientificName'],
        'confidence': data['identificationConfidence'],
      },
      'affectedParts': data['affectedParts'],
      'observations': data['observations'],
      'distribution': data['distribution'],
      'severity': data['severity'],
      'followUp': {
        'anotherPhotoHelpful': data['followUpPhotoHelpful'],
        'instruction': data['followUpInstruction'],
      },
    };
    final parsed = fromAiJson(nested);
    final modelName = data['modelName'];
    final timestamp = data['createdAt'];
    if (modelName is! String || modelName.isEmpty || modelName.length > 80) {
      throw const FormatException('Invalid observation model name.');
    }
    if (timestamp != null && timestamp is! Timestamp) {
      throw const FormatException('Invalid observation timestamp.');
    }
    if (data['source'] != 'firebase_ai_client') {
      throw const FormatException('Invalid observation source.');
    }
    return parsed.copyWith(
      id: id,
      modelName: modelName,
      createdAt: (timestamp as Timestamp?)?.toDate(),
    );
  }

  static Map<String, Object?> toFirestore(PlantObservation observation) {
    final modelName = observation.modelName;
    if (modelName == null || modelName.isEmpty || modelName.length > 80) {
      throw const FormatException('Observation model name is required.');
    }
    return {
      'schemaVersion': observation.schemaVersion,
      'plantVisible': observation.plantVisible,
      'imageQualityUsable': observation.imageQuality.usable,
      'imageQualityIssues': observation.imageQuality.issues
          .map((value) => value.name)
          .toList(growable: false),
      'possibleCommonName': observation.possibleIdentification.commonName,
      'possibleScientificName':
          observation.possibleIdentification.scientificName,
      'identificationConfidence': observation.possibleIdentification.confidence,
      'affectedParts': observation.affectedParts
          .map((value) => value.name)
          .toList(growable: false),
      'observations': observation.observations
          .map(
            (value) => {
              'type': value.type.name,
              'description': value.description,
              'confidence': value.confidence,
            },
          )
          .toList(growable: false),
      'distribution': observation.distribution,
      'severity': observation.severity.name,
      'followUpPhotoHelpful': observation.followUp.anotherPhotoHelpful,
      'followUpInstruction': observation.followUp.instruction,
      'modelName': modelName,
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'firebase_ai_client',
    };
  }

  static void _requireOnly(Map<String, dynamic> map, Set<String> keys) {
    if (map.keys.toSet().difference(keys).isNotEmpty ||
        !map.keys.toSet().containsAll(keys)) {
      throw const FormatException('Observation fields do not match schema.');
    }
  }

  static Map<String, dynamic> _map(Map<String, dynamic> map, String key) {
    final value = map[key];
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

  static String _string(
    Map<String, dynamic> map,
    String key,
    int maxLength, {
    bool allowEmpty = false,
  }) {
    final value = map[key];
    if (value is! String ||
        value.length > maxLength ||
        (!allowEmpty && value.trim().isEmpty) ||
        value != value.trim()) {
      throw FormatException('$key must be valid text.');
    }
    return value;
  }

  static String? _optionalString(
    Map<String, dynamic> map,
    String key,
    int maxLength,
  ) {
    if (map[key] == null) return null;
    return _string(map, key, maxLength);
  }

  static double _confidence(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! num) throw FormatException('$key must be a number.');
    final result = value.toDouble();
    if (!result.isFinite || result < 0 || result > 1) {
      throw FormatException('$key is outside the confidence range.');
    }
    return result;
  }

  static double? _optionalConfidence(Map<String, dynamic> map, String key) {
    if (map[key] == null) return null;
    return _confidence(map, key);
  }

  static T _enum<T extends Enum>(
    Map<String, dynamic> map,
    String key,
    List<T> values,
  ) {
    final raw = map[key];
    if (raw is! String) throw FormatException('$key must be an enum string.');
    return values.firstWhere(
      (value) => value.name == raw,
      orElse: () => throw FormatException('Unsupported $key value.'),
    );
  }

  static List<T> _enumList<T extends Enum>(
    Map<String, dynamic> map,
    String key,
    List<T> values,
    int maxLength,
  ) => _list(map, key, maxLength)
      .map((raw) => _enum(<String, dynamic>{key: raw}, key, values))
      .toList(growable: false);
}
