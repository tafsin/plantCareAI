import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/plant_observation/data/models/plant_observation_codec.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';

void main() {
  test('decodes a complete structured observation', () {
    final result = PlantObservationCodec.fromAiJson(validJson());
    expect(result.schemaVersion, 1);
    expect(result.severity, ObservationSeverity.moderate);
    expect(result.observations.single.type, VisualObservationType.yellowing);
  });

  test('persists only the allowlisted structured fields', () {
    final observation = PlantObservationCodec.fromAiJson(validJson())
        .copyWith(modelName: 'gemini-2.5-flash-lite');
    final data = PlantObservationCodec.toFirestore(observation);

    expect(data['source'], 'firebase_ai_client');
    expect(data['modelName'], 'gemini-2.5-flash-lite');
    expect(data, isNot(contains('imageBytes')));
    expect(data, isNot(contains('imageUrl')));
    expect(data, isNot(contains('rawResponse')));
    expect(data, isNot(contains('prompt')));
  });

  test('reads an existing observation created with the retired model', () {
    final oldObservation = PlantObservationCodec.fromAiJson(validJson())
        .copyWith(modelName: 'gemini-2.5-flash-lite');
    final data = PlantObservationCodec.toFirestore(oldObservation)
      ..['createdAt'] = Timestamp.fromDate(DateTime.utc(2026, 1, 1));

    final decoded = PlantObservationCodec.fromFirestoreData(
      id: 'old-observation',
      data: data,
    );

    expect(decoded.id, 'old-observation');
    expect(decoded.modelName, 'gemini-2.5-flash-lite');
    expect(decoded.schemaVersion, PlantObservation.currentSchemaVersion);
  });

  test('rejects malformed output, unexpected keys, and invalid confidence', () {
    expect(
      () => PlantObservationCodec.fromAiJson(validJson()..remove('followUp')),
      throwsFormatException,
    );
    expect(
      () => PlantObservationCodec.fromAiJson(
        validJson()..['rawHtml'] = '<b>x</b>',
      ),
      throwsFormatException,
    );
    final invalid = validJson();
    ((invalid['observations']! as List).first
            as Map<String, dynamic>)['confidence'] =
        1.1;
    expect(
      () => PlantObservationCodec.fromAiJson(invalid),
      throwsFormatException,
    );
  });

  test('rejects invalid enums and oversized arrays or strings', () {
    final badEnum = validJson()..['severity'] = 'critical';
    expect(
      () => PlantObservationCodec.fromAiJson(badEnum),
      throwsFormatException,
    );
    final oversized = validJson()..['affectedParts'] = List.filled(9, 'leaf');
    expect(
      () => PlantObservationCodec.fromAiJson(oversized),
      throwsFormatException,
    );
    final longText = validJson()
      ..['distribution'] = List.filled(501, 'x').join();
    expect(
      () => PlantObservationCodec.fromAiJson(longText),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> validJson() => {
  'schemaVersion': 1,
  'plantVisible': true,
  'imageQuality': {
    'usable': true,
    'issues': ['blurred'],
  },
  'possibleIdentification': {
    'commonName': 'Tomato',
    'scientificName': 'Solanum lycopersicum',
    'confidence': 0.82,
  },
  'affectedParts': ['leaf'],
  'observations': [
    {
      'type': 'yellowing',
      'description': 'Yellow areas are visible.',
      'confidence': 0.88,
    },
  ],
  'distribution': 'Mostly on lower leaves.',
  'severity': 'moderate',
  'followUp': {
    'anotherPhotoHelpful': true,
    'instruction': 'Photograph the leaf underside.',
  },
};
