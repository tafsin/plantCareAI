import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/care_history/data/models/care_log_codec.dart';
import 'package:plantcare_domain/care_history.dart';

void main() {
  final created = DateTime.utc(2026, 9, 3, 12);

  Map<String, dynamic> watering() => {
    'schemaVersion': 1,
    'type': 'watering',
    'occurredAt': Timestamp.fromDate(
      created.subtract(const Duration(hours: 1)),
    ),
    'notes': 'Watered after checking soil',
    'createdAt': Timestamp.fromDate(created),
    'source': 'user_entered',
    'wateringMethod': 'bottom',
    'amountMl': 250,
  };

  Map<String, dynamic> fertilizing() => {
    'schemaVersion': 1,
    'type': 'fertilizing',
    'occurredAt': Timestamp.fromDate(created),
    'createdAt': Timestamp.fromDate(created),
    'source': 'user_entered',
    'productName': 'Houseplant feed',
    'fertilizerForm': 'slow_release',
    'applicationNote': 'Applied as recorded on the package',
  };

  test('decodes a valid watering log', () {
    final log = CareLogCodec.fromMap('water-1', watering()) as WateringLog;
    expect(log.wateringMethod, WateringMethod.bottom);
    expect(log.amountMl, 250);
    expect(log.notes, 'Watered after checking soil');
  });

  test('decodes a valid fertilizing log', () {
    final log = CareLogCodec.fromMap('feed-1', fertilizing()) as FertilizingLog;
    expect(log.fertilizerForm, FertilizerForm.slowRelease);
    expect(log.productName, 'Houseplant feed');
  });

  test('rejects cross-type and unknown fields', () {
    expect(
      () => CareLogCodec.fromMap(
        'water-1',
        watering()..['fertilizerForm'] = 'liquid',
      ),
      throwsA(isA<Object>()),
    );
    expect(
      () => CareLogCodec.fromMap(
        'feed-1',
        fertilizing()..['wateringMethod'] = 'top',
      ),
      throwsA(isA<Object>()),
    );
  });

  test('rejects invalid enums', () {
    expect(
      () => CareLogCodec.fromMap(
        'water-1',
        watering()..['wateringMethod'] = 'spray',
      ),
      throwsA(isA<Object>()),
    );
    expect(
      () => CareLogCodec.fromMap(
        'feed-1',
        fertilizing()..['fertilizerForm'] = 'powder',
      ),
      throwsA(isA<Object>()),
    );
  });

  test('rejects invalid amounts', () {
    for (final value in [0, -1, 100001, double.infinity, double.nan]) {
      expect(
        () => CareLogCodec.fromMap('water-1', watering()..['amountMl'] = value),
        throwsA(isA<Object>()),
      );
    }
  });

  test('rejects empty, padded, and oversized optional strings', () {
    for (final value in ['', ' padded ', 'x' * 501]) {
      expect(
        () => CareLogCodec.fromMap('water-1', watering()..['notes'] = value),
        throwsA(isA<Object>()),
      );
    }
    expect(
      () => CareLogCodec.fromMap(
        'feed-1',
        fertilizing()..['productName'] = 'x' * 121,
      ),
      throwsA(isA<Object>()),
    );
  });
}
