import 'package:equatable/equatable.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/soil_check/domain/entities/soil_check.dart';

enum MoisturePreference {
  prefersConsistentlyMoist,
  allowSurfaceToDry,
  allowMoreCompleteDrying,
}

final class WateringPolicy extends Equatable {
  const WateringPolicy({
    required this.canonicalPlantKey,
    required this.preference,
    required this.supportedEnvironment,
    required this.evidenceChunkIds,
  });

  final String canonicalPlantKey;
  final MoisturePreference preference;
  final PlantEnvironment supportedEnvironment;
  final List<String> evidenceChunkIds;

  @override
  List<Object?> get props => [
    canonicalPlantKey,
    preference,
    supportedEnvironment,
    evidenceChunkIds,
  ];
}

abstract final class WateringPolicies {
  static const values = <String, WateringPolicy>{
    'tomato': WateringPolicy(
      canonicalPlantKey: 'tomato',
      preference: MoisturePreference.prefersConsistentlyMoist,
      supportedEnvironment: PlantEnvironment.outdoor,
      evidenceChunkIds: ['tomato__watering__consistent_deep_watering'],
    ),
    'pumpkin': WateringPolicy(
      canonicalPlantKey: 'pumpkin',
      preference: MoisturePreference.prefersConsistentlyMoist,
      supportedEnvironment: PlantEnvironment.outdoor,
      evidenceChunkIds: ['pumpkin__watering__deep_root_zone_watering'],
    ),
    'pothos': WateringPolicy(
      canonicalPlantKey: 'pothos',
      preference: MoisturePreference.allowSurfaceToDry,
      supportedEnvironment: PlantEnvironment.indoor,
      evidenceChunkIds: [
        'pothos__watering__dry_between_watering',
        'pothos__soil__well_drained_medium',
      ],
    ),
    'snake_plant': WateringPolicy(
      canonicalPlantKey: 'snake_plant',
      preference: MoisturePreference.allowMoreCompleteDrying,
      supportedEnvironment: PlantEnvironment.indoor,
      evidenceChunkIds: [
        'snake_plant__watering__dry_between_watering',
        'snake_plant__soil__fast_drainage',
      ],
    ),
    'peace_lily': WateringPolicy(
      canonicalPlantKey: 'peace_lily',
      preference: MoisturePreference.prefersConsistentlyMoist,
      supportedEnvironment: PlantEnvironment.indoor,
      evidenceChunkIds: [
        'peace_lily__watering__even_moisture',
        'peace_lily__soil__organic_well_drained_medium',
      ],
    ),
  };
}

final class WateringPolicyConfigurationException implements Exception {
  const WateringPolicyConfigurationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pure, deterministic decision table. Moist/wet always wait; slightly moist
/// always asks for another check; dry depends on the plant preference; very dry
/// waters all supported plants. An environment unsupported by the reviewed
/// policy requests another check instead of extrapolating evidence.
final class DeterministicWateringEngine {
  DeterministicWateringEngine({
    Map<String, WateringPolicy> policies = WateringPolicies.values,
  }) : _policies = Map.unmodifiable(policies) {
    _validate();
  }

  final Map<String, WateringPolicy> _policies;

  WateringGuidance calculate(WateringGuidanceInput input) {
    final policy = _policies[input.canonicalPlantKey];
    if (policy == null) {
      return const WateringGuidance(
        canonicalPlantKey: null,
        outcome: WateringOutcome.unsupportedPlant,
        title: 'Plant not supported',
        explanation:
            'This plant cannot be matched to a supported watering policy.',
        cautions: [
          'Do another soil check or seek plant-specific guidance rather than guessing.',
        ],
        evidenceChunkIds: [],
      );
    }
    if (input.environment != policy.supportedEnvironment) {
      return WateringGuidance(
        canonicalPlantKey: policy.canonicalPlantKey,
        outcome: WateringOutcome.inconsistentInput,
        title: 'Check the plant details',
        explanation: 'The saved environment does not match the environment covered by this plant policy.',
        cautions: _contextCautions(input),
        evidenceChunkIds: policy.evidenceChunkIds,
        suggestedCheckAfter: const Duration(hours: 12),
      );
    }

    final outcome = switch (input.moistureLevel) {
      SoilMoistureLevel.wet || SoilMoistureLevel.moist => WateringOutcome.wait,
      SoilMoistureLevel.slightlyMoist => WateringOutcome.checkAgain,
      SoilMoistureLevel.veryDry => WateringOutcome.waterNow,
      SoilMoistureLevel.dry => switch (policy.preference) {
        MoisturePreference.prefersConsistentlyMoist ||
        MoisturePreference.allowSurfaceToDry => WateringOutcome.waterNow,
        MoisturePreference.allowMoreCompleteDrying =>
          WateringOutcome.checkAgain,
      },
    };
    final isWet = input.moistureLevel == SoilMoistureLevel.wet;
    final cautions = <String>[
      ..._contextCautions(input),
      if (isWet) 'Wet soil can contribute to overwatering and root stress. Allow drainage and do not add water now.',
      if (policy.preference == MoisturePreference.allowMoreCompleteDrying)
        'Snake plants tolerate drier soil better than persistent saturation.',
    ];
    return WateringGuidance(
      canonicalPlantKey: policy.canonicalPlantKey,
      outcome: outcome,
      title: switch (outcome) {
        WateringOutcome.waterNow => 'Watering is appropriate now',
        WateringOutcome.wait => 'Wait before watering',
        WateringOutcome.checkAgain => 'Check the soil again',
        WateringOutcome.inconsistentInput => 'Check the plant details',
        WateringOutcome.unsupportedPlant => 'Plant not supported',
      },
      explanation: _explanation(policy, input.moistureLevel, outcome),
      cautions: cautions,
      evidenceChunkIds: policy.evidenceChunkIds,
      suggestedCheckAfter: switch (outcome) {
        WateringOutcome.wait || WateringOutcome.checkAgain => Duration(
          hours: input.environment == PlantEnvironment.outdoor ? 12 : 24,
        ),
        _ => null,
      },
    );
  }

  List<String> _contextCautions(WateringGuidanceInput input) => [
    if (input.environment == PlantEnvironment.outdoor) 'Recent and expected rainfall are not considered. Check local conditions before acting.',
    if (input.growingMedium == GrowingMedium.pot)
      'Confirm the pot drains freely; container size and material change drying time.'
    else
      'Ground soil can vary by location. Check more than one spot when practical.',
    'This qualitative finger test is not a numeric sensor measurement.',
  ];

  String _explanation(
    WateringPolicy policy,
    SoilMoistureLevel moisture,
    WateringOutcome outcome,
  ) => switch (outcome) {
    WateringOutcome.waterNow =>
      '${moisture.label} soil is at or below the threshold for this plant’s ${_preferenceLabel(policy.preference)} preference. Water thoroughly without using a fixed volume.',
    WateringOutcome.wait =>
      '${moisture.label} soil is above this plant’s watering threshold, so adding water now is not recommended.',
    WateringOutcome.checkAgain =>
      '${moisture.label} soil is near the decision boundary for this plant’s ${_preferenceLabel(policy.preference)} preference. Recheck below the surface before deciding.',
    WateringOutcome.inconsistentInput => 'The inputs need confirmation.',
    WateringOutcome.unsupportedPlant => 'No supported policy is available.',
  };

  String _preferenceLabel(MoisturePreference value) => switch (value) {
    MoisturePreference.prefersConsistentlyMoist => 'consistently moist soil',
    MoisturePreference.allowSurfaceToDry => 'surface drying',
    MoisturePreference.allowMoreCompleteDrying => 'more complete drying',
  };

  void _validate() {
    if (_policies.isEmpty) {
      throw const WateringPolicyConfigurationException('Policies are empty.');
    }
    for (final entry in _policies.entries) {
      final policy = entry.value;
      if (entry.key != policy.canonicalPlantKey ||
          policy.evidenceChunkIds.isEmpty ||
          policy.evidenceChunkIds.toSet().length !=
              policy.evidenceChunkIds.length ||
          policy.evidenceChunkIds.any(
            (id) =>
                !id.startsWith('${policy.canonicalPlantKey}__') ||
                id.contains('/'),
          )) {
        throw WateringPolicyConfigurationException(
          'Invalid watering policy for ${entry.key}.',
        );
      }
    }
  }
}
