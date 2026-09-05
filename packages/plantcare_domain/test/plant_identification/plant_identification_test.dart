import 'package:test/test.dart';
import 'package:plantcare_domain/plant_identification.dart';

void main() {
  for (final entry in {
    0.59: IdentificationConfidence.low,
    0.60: IdentificationConfidence.medium,
    0.84: IdentificationConfidence.medium,
    0.85: IdentificationConfidence.high,
    1.0: IdentificationConfidence.high,
  }.entries) {
    test('confidence boundary ${entry.key}', () {
      final candidate = PlantIdentificationCandidate(
        commonName: 'Pothos',
        scientificName: 'Epipremnum aureum',
        confidence: entry.key,
        visibleEvidence: ['Heart shaped leaves'],
      );
      final result = PlantIdentificationResult(
        imageStatus: IdentificationImageStatus.usableImage,
        candidates: [candidate],
      );
      expect(result.confidence, entry.value);
      expect(() => result.candidates.clear(), throwsUnsupportedError);
      expect(() => candidate.visibleEvidence.clear(), throwsUnsupportedError);
    });
  }
  test('supported plants use canonical names and detect conflicts', () {
    for (final name in [
      'Tomato',
      'Pumpkin',
      'Pothos',
      'Snake plant',
      'Peace lily',
    ]) {
      expect(OnboardingPlantSupport.isSupported(name, null), isTrue);
    }
    expect(
      OnboardingPlantSupport.isSupported('Monstera', 'Monstera deliciosa'),
      isFalse,
    );
    expect(
      OnboardingPlantSupport.isSupported('Tomato', 'Epipremnum aureum'),
      isFalse,
    );
    expect(
      OnboardingPlantSupport.hasNameConflict('Tomato', 'Epipremnum aureum'),
      isTrue,
    );
  });
  test('rejects non-finite confidence', () {
    for (final value in [double.nan, double.infinity]) {
      expect(
        () => PlantIdentificationCandidate(
          commonName: 'Pothos',
          scientificName: 'Epipremnum aureum',
          confidence: value,
          visibleEvidence: ['Leaves'],
        ),
        throwsFormatException,
      );
    }
  });
}
