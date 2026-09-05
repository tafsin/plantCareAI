import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/plant_identification.dart';
import 'package:plantcare_domain/plant_identification.dart';

Map<String, dynamic> candidate() => {
  'commonName': 'Pothos',
  'scientificName': 'Epipremnum aureum',
  'confidence': 0.9,
  'visibleEvidence': ['Heart shaped leaves'],
};
Map<String, dynamic> payload() => {
  'schemaVersion': 1,
  'imageStatus': 'usable_image',
  'identification_candidates': [candidate()],
};
void main() {
  test('strict versioned result with optional ambiguity', () {
    final json = payload();
    (json['identification_candidates'] as List).first['ambiguityNote'] =
        'Similar leaf shapes occur in other plants';
    final result = PlantIdentificationCodec.decode(jsonEncode(json));
    expect(result.candidates.single.commonName, 'Pothos');
    expect(result.confidence, IdentificationConfidence.high);
  });
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'missing field': (p) => p.remove('schemaVersion'),
    'extra root field': (p) => p['raw'] = 'no',
    'future version': (p) => p['schemaVersion'] = 2,
    'floating version': (p) => p['schemaVersion'] = 1.0,
    'invalid enum': (p) => p['imageStatus'] = 'great',
    'four candidates': (p) =>
        p['identification_candidates'] = List.generate(4, (_) => candidate()),
    'no plant with candidates': (p) => p['imageStatus'] = 'no_plant_visible',
    'bad quality with candidates': (p) =>
        p['imageStatus'] = 'insufficient_image_quality',
  };
  for (final entry in mutations.entries) {
    test('rejects ${entry.key}', () {
      final p = payload();
      entry.value(p);
      expect(
        () => PlantIdentificationCodec.decode(jsonEncode(p)),
        throwsFormatException,
      );
    });
  }
  final badFields = <String, Object?>{
    'confidence': -0.1,
    'commonName': ' Pothos',
    'scientificName': 'https://example.com',
    'visibleEvidence': <String>[],
    'ambiguityNote': null,
    'unknown': 'extra',
  };
  for (final entry in badFields.entries) {
    test('rejects bad ${entry.key}', () {
      final c = candidate()..[entry.key] = entry.value;
      expect(
        () => PlantIdentificationCodec.decode(
          jsonEncode(payload()..['identification_candidates'] = [c]),
        ),
        throwsFormatException,
      );
    });
  }
  for (final value in [1.1, '0.9', null, true]) {
    test(
      'rejects confidence $value',
      () => expect(
        () => PlantIdentificationCodec.decode(
          jsonEncode(
            payload()
              ..['identification_candidates'] = [
                candidate()..['confidence'] = value,
              ],
          ),
        ),
        throwsFormatException,
      ),
    );
  }
  for (final value in [
    '<b>Leaf</b>',
    '**leaf**',
    'www.example.org',
    'example.xyz/path',
    '90 percent certain',
    'mailto:plant@example.xyz',
    'Leaves 90%',
    'Apply fertilizer',
    'Water weekly',
    'x' * 161,
    'leaf\nshape',
  ]) {
    test(
      'rejects evidence $value',
      () => expect(
        () => PlantIdentificationCodec.decode(
          jsonEncode(
            payload()
              ..['identification_candidates'] = [
                candidate()..['visibleEvidence'] = [value],
              ],
          ),
        ),
        throwsFormatException,
      ),
    );
  }
  for (final key in candidate().keys) {
    test(
      'rejects missing candidate $key',
      () => expect(
        () => PlantIdentificationCodec.decode(
          jsonEncode(
            payload()
              ..['identification_candidates'] = [candidate()..remove(key)],
          ),
        ),
        throwsFormatException,
      ),
    );
  }
  test('rejects oversized names, evidence counts and ambiguity', () {
    for (final field in <String, Object>{
      'commonName': 'a' * 81,
      'scientificName': 'a' * 121,
      'visibleEvidence': List.filled(5, 'Green leaves'),
      'ambiguityNote': 'a' * 201,
    }.entries) {
      expect(
        () => PlantIdentificationCodec.decode(
          jsonEncode(
            payload()
              ..['identification_candidates'] = [
                candidate()..[field.key] = field.value,
              ],
          ),
        ),
        throwsFormatException,
      );
    }
  });
  test('plant names containing water remain identifiable', () {
    final data = payload()
      ..['identification_candidates'] = [
        candidate()
          ..['commonName'] = 'Water lily'
          ..['scientificName'] = 'Nymphaea alba',
      ];
    expect(
      PlantIdentificationCodec.decode(jsonEncode(data))
          .candidates
          .single
          .commonName,
      'Water lily',
    );
  });
  test('rejects oversized raw output and non-object JSON', () {
    for (final value in [' ' * 6001, '[]', 'null', '```json {} ```']) {
      expect(
        () => PlantIdentificationCodec.decode(value),
        throwsFormatException,
      );
    }
  });
  for (final status in IdentificationImageStatus.values) {
    test('accepts empty candidates for ${status.name}', () {
      expect(
        PlantIdentificationCodec.decode(
          jsonEncode(
            payload()
              ..['imageStatus'] = status.wireValue
              ..['identification_candidates'] = [],
          ),
        ).candidates,
        isEmpty,
      );
    });
  }
}
