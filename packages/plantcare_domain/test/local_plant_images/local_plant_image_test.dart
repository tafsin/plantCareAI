import 'package:plantcare_domain/local_plant_images.dart';
import 'package:test/test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 9);

  test('metadata has value equality and portable purpose values', () {
    final first = LocalPlantImage(
      id: '0123456789abcdef',
      purpose: LocalPlantImagePurpose.healthCheck,
      plantId: 'plant-1',
      observationId: 'observation-1',
      createdAt: createdAt,
      byteSize: 42,
    );
    final second = LocalPlantImage(
      id: '0123456789abcdef',
      purpose: LocalPlantImagePurpose.healthCheck,
      plantId: 'plant-1',
      observationId: 'observation-1',
      createdAt: createdAt,
      byteSize: 42,
    );

    expect(first, second);
    expect(first.purpose.value, 'health_check');
    expect(
      LocalPlantImagePurposeValue.parse('plant_identification'),
      LocalPlantImagePurpose.plantIdentification,
    );
  });

  test('identification images reject observation associations', () {
    expect(
      () => validateLocalPlantImage(
        LocalPlantImage(
          id: '0123456789abcdef',
          purpose: LocalPlantImagePurpose.plantIdentification,
          plantId: 'plant-1',
          observationId: 'observation-1',
          createdAt: createdAt,
          byteSize: 42,
        ),
      ),
      throwsFormatException,
    );
  });

  test('health-check images require a valid observation association', () {
    expect(
      () => validateLocalPlantImage(
        LocalPlantImage(
          id: '0123456789abcdef',
          purpose: LocalPlantImagePurpose.healthCheck,
          plantId: 'plant-1',
          createdAt: createdAt,
          byteSize: 42,
        ),
      ),
      throwsFormatException,
    );
  });

  test('metadata rejects invalid identifiers and byte sizes', () {
    expect(
      () => validateLocalPlantImage(
        LocalPlantImage(
          id: 'short',
          purpose: LocalPlantImagePurpose.plantIdentification,
          plantId: 'bad/id',
          createdAt: createdAt,
          byteSize: 0,
        ),
      ),
      throwsFormatException,
    );
  });
}
