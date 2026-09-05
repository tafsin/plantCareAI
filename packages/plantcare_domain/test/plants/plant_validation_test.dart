import 'package:plantcare_domain/plants.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes optional values and removes pot size for ground plants', () {
    const draft = PlantDraft(
      commonName: '  Basil  ',
      scientificName: '  ',
      environment: PlantEnvironment.outdoor,
      growingMedium: GrowingMedium.ground,
      potSizeLiters: 4,
      sunlight: Sunlight.full,
      growthStage: GrowthStage.vegetative,
      notes: '  Edible  ',
    );

    final normalized = draft.normalized();
    expect(normalized.commonName, 'Basil');
    expect(normalized.scientificName, isNull);
    expect(normalized.potSizeLiters, isNull);
    expect(normalized.notes, 'Edible');
  });

  test('enforces shared field limits', () {
    expect(PlantValidator.commonName(''), isNotNull);
    expect(PlantValidator.commonName(List.filled(81, 'x').join()), isNotNull);
    expect(
      PlantValidator.scientificName(List.filled(121, 'x').join()),
      isNotNull,
    );
    expect(PlantValidator.notes(List.filled(1001, 'x').join()), isNotNull);
    expect(PlantValidator.potSize('0', GrowingMedium.pot), isNotNull);
    expect(PlantValidator.potSize('10001', GrowingMedium.pot), isNotNull);
    expect(PlantValidator.potSize('anything', GrowingMedium.ground), isNull);
  });
}
