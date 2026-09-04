import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/soil_check.dart';
import 'package:test/test.dart';

void main() {
  final engine = DeterministicWateringEngine();

  group('deterministic watering decision table', () {
    for (final policy in WateringPolicies.values.values) {
      for (final moisture in SoilMoistureLevel.values) {
        test('${policy.canonicalPlantKey} handles ${moisture.value}', () {
          final result = engine.calculate(_input(policy, moisture));
          expect(result.canonicalPlantKey, policy.canonicalPlantKey);
          expect(result.evidenceChunkIds, isNotEmpty);
          expect(
            result.evidenceChunkIds.every(
              (id) => id.startsWith('${policy.canonicalPlantKey}__'),
            ),
            isTrue,
          );
          if (moisture == SoilMoistureLevel.wet ||
              moisture == SoilMoistureLevel.moist) {
            expect(result.outcome, WateringOutcome.wait);
          }
        });
      }
    }

    test('snake plant dry threshold differs from moisture-loving plants', () {
      expect(
        engine
            .calculate(
              _input(
                WateringPolicies.values['snake_plant']!,
                SoilMoistureLevel.dry,
              ),
            )
            .outcome,
        WateringOutcome.checkAgain,
      );
      for (final key in ['tomato', 'peace_lily']) {
        expect(
          engine
              .calculate(
                _input(WateringPolicies.values[key]!, SoilMoistureLevel.dry),
              )
              .outcome,
          WateringOutcome.waterNow,
        );
      }
    });

    test('unsupported plant is not guessed', () {
      final result = engine.calculate(
        WateringGuidanceInput(
          canonicalPlantKey: 'fern',
          environment: PlantEnvironment.indoor,
          growingMedium: GrowingMedium.pot,
          moistureLevel: SoilMoistureLevel.dry,
          checkTime: DateTime.utc(2026),
        ),
      );
      expect(result.outcome, WateringOutcome.unsupportedPlant);
      expect(result.evidenceChunkIds, isEmpty);
    });

    test('same input always produces same result', () {
      final input = _input(
        WateringPolicies.values['pothos']!,
        SoilMoistureLevel.slightlyMoist,
      );
      expect(engine.calculate(input), engine.calculate(input));
    });

    test('outdoor caution states rainfall is not considered', () {
      final result = engine.calculate(
        _input(WateringPolicies.values['tomato']!, SoilMoistureLevel.dry),
      );
      expect(
        result.cautions.join(' '),
        contains('rainfall are not considered'),
      );
    });

    test('pot and ground cautions differ', () {
      final policy = WateringPolicies.values['tomato']!;
      final pot = engine.calculate(
        _input(policy, SoilMoistureLevel.dry, medium: GrowingMedium.pot),
      );
      final ground = engine.calculate(
        _input(policy, SoilMoistureLevel.dry, medium: GrowingMedium.ground),
      );
      expect(pot.cautions.join(' '), contains('pot drains'));
      expect(ground.cautions.join(' '), contains('more than one spot'));
    });

    test('wet includes root-stress caution', () {
      final result = engine.calculate(
        _input(WateringPolicies.values['peace_lily']!, SoilMoistureLevel.wet),
      );
      expect(result.cautions.join(' '), contains('root stress'));
    });

    test('unsupported environment is inconsistent input', () {
      final policy = WateringPolicies.values['snake_plant']!;
      final result = engine.calculate(
        WateringGuidanceInput(
          canonicalPlantKey: policy.canonicalPlantKey,
          environment: PlantEnvironment.outdoor,
          growingMedium: GrowingMedium.pot,
          moistureLevel: SoilMoistureLevel.dry,
          checkTime: DateTime.utc(2026),
        ),
      );
      expect(result.outcome, WateringOutcome.inconsistentInput);
    });

    test('invalid policy configuration is rejected', () {
      expect(
        () => DeterministicWateringEngine(
          policies: {
            'tomato': const WateringPolicy(
              canonicalPlantKey: 'tomato',
              preference: MoisturePreference.prefersConsistentlyMoist,
              supportedEnvironment: PlantEnvironment.outdoor,
              evidenceChunkIds: ['wrong__watering__id'],
            ),
          },
        ),
        throwsA(isA<WateringPolicyConfigurationException>()),
      );
    });
  });
}

WateringGuidanceInput _input(
  WateringPolicy policy,
  SoilMoistureLevel moisture, {
  GrowingMedium medium = GrowingMedium.ground,
}) => WateringGuidanceInput(
  canonicalPlantKey: policy.canonicalPlantKey,
  environment: policy.supportedEnvironment,
  growingMedium: medium,
  moistureLevel: moisture,
  checkTime: DateTime.utc(2026, 9, 3, 12),
);
