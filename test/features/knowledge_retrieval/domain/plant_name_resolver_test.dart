import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

import '../../../helpers/fake_plant_observation_dependencies.dart';

void main() {
  group('canonicalPlantKeyFor', () {
    test('resolves every supported common name', () {
      expect(canonicalPlantKeyFor('tomato'), 'tomato');
      expect(canonicalPlantKeyFor('pumpkin'), 'pumpkin');
      expect(canonicalPlantKeyFor('pothos'), 'pothos');
      expect(canonicalPlantKeyFor('snake plant'), 'snake_plant');
      expect(canonicalPlantKeyFor('peace lily'), 'peace_lily');
    });

    test('resolves scientific names and ingestion aliases', () {
      const expected = {
        'Solanum lycopersicum': 'tomato',
        'Lycopersicon esculentum': 'tomato',
        'Lycopersicon lycopersicum': 'tomato',
        'Cucurbita pepo': 'pumpkin',
        'golden pothos': 'pothos',
        "devil's ivy": 'pothos',
        'Epipremnum aureum': 'pothos',
        'Scindapsus aureus': 'pothos',
        "mother-in-law's tongue": 'snake_plant',
        'Dracaena trifasciata': 'snake_plant',
        'Sansevieria trifasciata': 'snake_plant',
        'Spathiphyllum': 'peace_lily',
        'Spathiphyllum wallisii': 'peace_lily',
      };
      for (final entry in expected.entries) {
        expect(canonicalPlantKeyFor(entry.key), entry.value, reason: entry.key);
      }
    });

    test(
      'normalizes case, whitespace, punctuation, apostrophes and separators',
      () {
        expect(canonicalPlantKeyFor('  GOLDEN__POTHOS!! '), 'pothos');
        expect(canonicalPlantKeyFor('Devil’s-Ivy'), 'pothos');
        expect(canonicalPlantKeyFor('mother-in-law’s   tongue'), 'snake_plant');
        expect(canonicalPlantKeyFor('PEACE_LILY'), 'peace_lily');
      },
    );

    test('does not fuzzy match unknown plants', () {
      expect(canonicalPlantKeyFor('tomatillo'), isNull);
      expect(canonicalPlantKeyFor('peace lilies hybrid'), isNull);
    });
  });

  group('PlantNameResolver', () {
    const resolver = PlantNameResolver();

    test('ignores AI identification below 0.70', () {
      final result = resolver.resolve(
        _plant(commonName: 'Monstera'),
        _observation(aiCommon: 'Tomato', confidence: 0.69),
      );
      expect(result.status, PlantResolutionStatus.unsupported);
    });

    test('profile scientific name takes precedence without conflict', () {
      final result = resolver.resolve(
        _plant(commonName: 'Garden plant', scientificName: 'Cucurbita pepo'),
        _observation(aiCommon: 'Pumpkin', confidence: 0.95),
      );
      expect(result.canonicalKey, 'pumpkin');
    });

    test('profile and qualifying AI disagreement requires selection', () {
      final result = resolver.resolve(
        _plant(commonName: 'Tomato'),
        _observation(aiCommon: 'Pumpkin', confidence: 0.70),
      );
      expect(result.status, PlantResolutionStatus.conflict);
      expect(result.candidates, ['tomato', 'pumpkin']);
    });
  });
}

Plant _plant({required String commonName, String? scientificName}) => Plant(
  id: 'plant-1',
  commonName: commonName,
  scientificName: scientificName,
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.mature,
);

PlantObservation _observation({String? aiCommon, double? confidence}) =>
    PlantObservation(
      schemaVersion: sampleObservation.schemaVersion,
      plantVisible: sampleObservation.plantVisible,
      imageQuality: sampleObservation.imageQuality,
      possibleIdentification: PossiblePlantIdentification(
        commonName: aiCommon,
        confidence: confidence,
      ),
      affectedParts: sampleObservation.affectedParts,
      observations: sampleObservation.observations,
      distribution: sampleObservation.distribution,
      severity: sampleObservation.severity,
      followUp: sampleObservation.followUp,
    );
