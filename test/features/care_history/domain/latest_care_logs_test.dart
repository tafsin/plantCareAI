import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/services/latest_care_logs.dart';

void main() {
  final early = DateTime.utc(2026, 9, 1);
  final late = DateTime.utc(2026, 9, 2);

  test('finds latest watering by occurredAt', () {
    final result = latestCareLogs([
      WateringLog(
        id: 'later',
        occurredAt: late,
        wateringMethod: WateringMethod.top,
      ),
      WateringLog(
        id: 'created-later',
        occurredAt: early,
        createdAt: DateTime.utc(2030),
        wateringMethod: WateringMethod.bottom,
      ),
    ]);
    expect(result.watering?.id, 'later');
  });

  test('finds latest fertilizer independently', () {
    final result = latestCareLogs([
      FertilizingLog(
        id: 'early',
        occurredAt: early,
        fertilizerForm: FertilizerForm.compost,
      ),
      FertilizingLog(
        id: 'late',
        occurredAt: late,
        fertilizerForm: FertilizerForm.liquid,
      ),
      WateringLog(
        id: 'water',
        occurredAt: late,
        wateringMethod: WateringMethod.top,
      ),
    ]);
    expect(result.fertilizing?.id, 'late');
    expect(result.watering?.id, 'water');
  });

  test('equal timestamps use document id deterministically', () {
    final result = latestCareLogs([
      WateringLog(
        id: 'a',
        occurredAt: late,
        wateringMethod: WateringMethod.top,
      ),
      WateringLog(
        id: 'z',
        occurredAt: late,
        wateringMethod: WateringMethod.bottom,
      ),
    ]);
    expect(result.watering?.id, 'z');
  });
}
