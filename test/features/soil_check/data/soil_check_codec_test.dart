import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/soil_check/data/models/soil_check_codec.dart';

void main() {
  test('reads a historical v1 record without rewriting it', () {
    final record = SoilCheckCodec.fromFirestoreData(
      id: 'legacy',
      data: _data(),
    );
    expect(record.guidance.datasetVersion, '2026-09-03-v1');
  });

  test('reads a current v2 record and rejects unknown versions', () {
    final current = SoilCheckCodec.fromFirestoreData(
      id: 'current',
      data: _data()..['datasetVersion'] = '2026-09-03-v2',
    );
    expect(current.guidance.datasetVersion, '2026-09-03-v2');
    expect(
      () => SoilCheckCodec.fromFirestoreData(
        id: 'future',
        data: _data()..['datasetVersion'] = 'future',
      ),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _data() => {
  'schemaVersion': 1,
  'policyVersion': 'manual-watering-v1',
  'moistureLevel': 'dry',
  'method': 'manual_finger_test',
  'outcome': 'water_now',
  'title': 'Water now',
  'explanation': 'The manual check reached the policy threshold.',
  'cautions': ['Check local conditions.'],
  'canonicalPlantKey': 'tomato',
  'evidenceChunkIds': ['tomato__watering__consistent_deep_watering'],
  'environmentSnapshot': 'outdoor',
  'growingMediumSnapshot': 'ground',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1)),
  'source': 'deterministic_client_policy',
};
