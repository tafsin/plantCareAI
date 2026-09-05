import 'dart:convert';

import 'package:plantcare_domain/plant_identification.dart';

abstract final class PlantIdentificationCodec {
  static PlantIdentificationResult decode(String text) {
    if (text.length > 6000) throw const FormatException('Response too large.');
    final decoded = jsonDecode(text);
    final root = _object(decoded, {
      'schemaVersion',
      'imageStatus',
      'identification_candidates',
    });
    if (root['schemaVersion'] is! int || root['schemaVersion'] != 1) {
      throw const FormatException('Invalid version.');
    }
    final status = IdentificationImageStatus.values
        .where((s) => s.wireValue == root['imageStatus'])
        .firstOrNull;
    final candidates = root['identification_candidates'];
    if (status == null || candidates is! List || candidates.length > 3) {
      throw const FormatException('Invalid result.');
    }
    return PlantIdentificationResult(
      imageStatus: status,
      candidates: candidates.map((value) {
        final candidate = _object(
          value,
          {'commonName', 'scientificName', 'confidence', 'visibleEvidence'},
          optional: {'ambiguityNote'},
        );
        final confidence = candidate['confidence'];
        final evidence = candidate['visibleEvidence'];
        if (confidence is! num ||
            evidence is! List ||
            evidence.any((e) => e is! String)) {
          throw const FormatException('Invalid candidate.');
        }
        if (candidate.containsKey('ambiguityNote') &&
            candidate['ambiguityNote'] is! String) {
          throw const FormatException('Invalid ambiguity note.');
        }
        return PlantIdentificationCandidate(
          commonName: _string(candidate['commonName']),
          scientificName: _string(candidate['scientificName']),
          confidence: confidence.toDouble(),
          visibleEvidence: evidence.cast<String>(),
          ambiguityNote: candidate['ambiguityNote'] as String?,
        );
      }).toList(),
    );
  }

  static String _string(Object? value) {
    if (value is! String) throw const FormatException('Expected text.');
    return value;
  }

  static Map<String, dynamic> _object(
    Object? value,
    Set<String> required, {
    Set<String> optional = const {},
  }) {
    if (value is! Map<String, dynamic> ||
        !value.keys.toSet().containsAll(required) ||
        value.keys.any(
          (key) => !required.contains(key) && !optional.contains(key),
        )) {
      throw const FormatException('Unexpected fields.');
    }
    return value;
  }
}
