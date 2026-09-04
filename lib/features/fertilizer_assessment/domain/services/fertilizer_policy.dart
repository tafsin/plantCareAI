import 'package:equatable/equatable.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/entities/fertilizer_assessment.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

final class FertilizerPolicy extends Equatable {
  const FertilizerPolicy({
    required this.canonicalPlantKey,
    required this.environment,
    required this.growthStages,
    required this.category,
    required this.evidenceChunkIds,
    required this.cautions,
    this.minimumReviewInterval,
  });

  final String canonicalPlantKey;
  final PlantEnvironment environment;
  final Set<GrowthStage> growthStages;
  final FertilizerCategory category;
  final Duration? minimumReviewInterval;
  final List<String> evidenceChunkIds;
  final List<String> cautions;

  @override
  List<Object?> get props => [
    canonicalPlantKey,
    environment,
    growthStages,
    category,
    minimumReviewInterval,
    evidenceChunkIds,
    cautions,
  ];
}

abstract final class FertilizerPolicies {
  static const values = <String, FertilizerPolicy>{
    'tomato': FertilizerPolicy(
      canonicalPlantKey: 'tomato',
      environment: PlantEnvironment.outdoor,
      growthStages: {GrowthStage.fruiting},
      category: FertilizerCategory.vegetableOrTomato,
      evidenceChunkIds: [
        'tomato__nutrient_guidance__fertilizer_soil_test_and_fruiting',
        'tomato__nutrient_guidance__fertilizer_wait_while_stressed',
      ],
      cautions: [
        'A soil test may show that additional fertilizer is unnecessary.',
        'Too much nitrogen can delay fruiting.',
      ],
    ),
    'pumpkin': FertilizerPolicy(
      canonicalPlantKey: 'pumpkin',
      environment: PlantEnvironment.outdoor,
      growthStages: {
        GrowthStage.vegetative,
        GrowthStage.flowering,
        GrowthStage.fruiting,
      },
      category: FertilizerCategory.generalGarden,
      evidenceChunkIds: [
        'pumpkin__nutrient_guidance__fertilizer_soil_test_and_runners',
        'pumpkin__nutrient_guidance__fertilizer_wait_while_stressed',
      ],
      cautions: [
        'Use a soil test to determine whether added nutrients are warranted.',
      ],
    ),
    'pothos': FertilizerPolicy(
      canonicalPlantKey: 'pothos',
      environment: PlantEnvironment.indoor,
      growthStages: {GrowthStage.vegetative, GrowthStage.mature},
      category: FertilizerCategory.balancedHouseplant,
      minimumReviewInterval: Duration(days: 60),
      evidenceChunkIds: [
        'pothos__nutrient_guidance__fertilizer_active_growth_interval',
        'pothos__nutrient_guidance__fertilizer_stress_and_repot_wait',
      ],
      cautions: [
        'Do not fertilize during winter dormancy.',
        'Excess fertilizer salts can burn roots.',
      ],
    ),
    'snake_plant': FertilizerPolicy(
      canonicalPlantKey: 'snake_plant',
      environment: PlantEnvironment.indoor,
      growthStages: {GrowthStage.vegetative, GrowthStage.mature},
      category: FertilizerCategory.balancedHouseplant,
      evidenceChunkIds: [
        'snake_plant__nutrient_guidance__minimal_fertilizer_active_season',
        'snake_plant__nutrient_guidance__fertilizer_stress_and_repot_wait',
      ],
      cautions: ['Snake plants have minimal fertilizer needs.'],
    ),
    'peace_lily': FertilizerPolicy(
      canonicalPlantKey: 'peace_lily',
      environment: PlantEnvironment.indoor,
      growthStages: {
        GrowthStage.vegetative,
        GrowthStage.flowering,
        GrowthStage.mature,
      },
      category: FertilizerCategory.balancedHouseplant,
      evidenceChunkIds: [
        'peace_lily__nutrient_guidance__low_fertility_needs',
        'peace_lily__nutrient_guidance__fertilizer_active_growth_stress_and_repot',
      ],
      cautions: [
        'Peace lilies have low fertilizer needs.',
        'Overfertilizing can burn leaf tips and roots.',
      ],
    ),
  };
}

final class FertilizerPolicyConfigurationException implements Exception {
  const FertilizerPolicyConfigurationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Deterministic decision table:
/// - unknown activity requests more information;
/// - stress always avoids fertilizer;
/// - slow/dormant growth waits;
/// - recently repotted indoor plants wait, while outdoor evidence is
///   insufficient;
/// - unsupported environments and growth stages return insufficient evidence;
/// - a supported active-growth state may consider fertilizer, except a recent
///   log inside an explicit minimum interval waits and missing interval-based
///   history requests more information.
final class DeterministicFertilizerEngine {
  DeterministicFertilizerEngine({
    Map<String, FertilizerPolicy> policies = FertilizerPolicies.values,
  }) : _policies = Map.unmodifiable(policies) {
    _validate();
  }

  final Map<String, FertilizerPolicy> _policies;

  FertilizerGuidance calculate(FertilizerAssessmentInput input) {
    final policy = _policies[input.canonicalPlantKey];
    if (policy == null) {
      return const FertilizerGuidance(
        canonicalPlantKey: null,
        outcome: FertilizerOutcome.unsupportedPlant,
        title: 'Plant not supported',
        explanation:
            'This plant cannot be matched to a reviewed fertilizer policy.',
        cautions: ['Seek plant-specific guidance rather than guessing.'],
        evidenceChunkIds: [],
      );
    }
    final commonCautions = <String>[
      ...policy.cautions,
      'This is general guidance, not a dosage instruction.',
      'Follow the product label and never exceed it.',
      'Fertilizer is not a treatment for disease or visible symptoms.',
    ];

    if (input.environment != policy.environment) {
      return _guidance(
        policy,
        input,
        FertilizerOutcome.insufficientEvidence,
        'Environment not covered',
        'The reviewed policy does not cover this plant in the saved environment.',
        commonCautions,
      );
    }

    return switch (input.growthActivity) {
      GrowthActivity.unknown => _guidance(
        policy,
        input,
        FertilizerOutcome.moreInformationNeeded,
        'More information needed',
        'Confirm whether the plant is actively growing, resting, stressed, or recently repotted before considering fertilizer.',
        commonCautions,
      ),
      GrowthActivity.stressedOrUnhealthy => _guidance(
        policy,
        input,
        FertilizerOutcome.avoidWhileStressed,
        'Avoid fertilizer while stressed',
        'Do not use fertilizer as medicine. Identify and address the cause of stress before reviewing fertilizer again.',
        commonCautions,
      ),
      GrowthActivity.slowOrDormant => _guidance(
        policy,
        input,
        FertilizerOutcome.wait,
        'Wait while growth is slow',
        'The audited guidance limits routine fertilizer to active growth.',
        commonCautions,
      ),
      GrowthActivity.recentlyRepotted => _guidance(
        policy,
        input,
        policy.environment == PlantEnvironment.indoor
            ? FertilizerOutcome.wait
            : FertilizerOutcome.insufficientEvidence,
        policy.environment == PlantEnvironment.indoor
            ? 'Wait after repotting'
            : 'Repotting guidance is not available',
        policy.environment == PlantEnvironment.indoor
            ? 'Fresh potting mix commonly contains nutrients. The audited guidance supports waiting before regular fertilizer resumes.'
            : 'The reviewed outdoor crop evidence does not establish a safe fertilizer decision from “recently repotted” alone.',
        commonCautions,
      ),
      GrowthActivity.activeGrowth => _active(policy, input, commonCautions),
    };
  }

  FertilizerGuidance _active(
    FertilizerPolicy policy,
    FertilizerAssessmentInput input,
    List<String> cautions,
  ) {
    if (!policy.growthStages.contains(input.growthStage)) {
      return _guidance(
        policy,
        input,
        FertilizerOutcome.insufficientEvidence,
        'Growth stage not covered',
        'The reviewed policy does not support routine fertilizer guidance for this saved growth stage.',
        cautions,
      );
    }
    final interval = policy.minimumReviewInterval;
    final last = input.lastFertilizedAt;
    if (interval != null && last == null) {
      return _guidance(
        policy,
        input,
        FertilizerOutcome.moreInformationNeeded,
        'Fertilizer history needed',
        'No fertilizer history is available. That does not prove fertilizer is needed, so confirm prior care before deciding.',
        cautions,
      );
    }
    if (interval != null && last != null) {
      final reviewAt = last.add(interval);
      if (input.assessmentTime.isBefore(reviewAt)) {
        return _guidance(
          policy,
          input,
          FertilizerOutcome.wait,
          'Wait before reviewing fertilizer again',
          'The latest fertilizer log is inside the audited minimum review interval.',
          cautions,
          suggestedReviewAt: reviewAt,
        );
      }
    }
    return _guidance(
      policy,
      input,
      FertilizerOutcome.considerFertilizing,
      'Fertilizer may be considered',
      'The plant is in an audited active-growth condition. This is permission to consider the broad category, not a claim that fertilizer is due or required.',
      cautions,
      category: policy.category,
    );
  }

  FertilizerGuidance _guidance(
    FertilizerPolicy policy,
    FertilizerAssessmentInput input,
    FertilizerOutcome outcome,
    String title,
    String explanation,
    List<String> cautions, {
    FertilizerCategory? category,
    DateTime? suggestedReviewAt,
  }) => FertilizerGuidance(
    canonicalPlantKey: policy.canonicalPlantKey,
    outcome: outcome,
    fertilizerCategory: category,
    title: title,
    explanation: explanation,
    cautions: cautions,
    evidenceChunkIds: policy.evidenceChunkIds,
    lastFertilizedAt: input.lastFertilizedAt,
    suggestedReviewAt: suggestedReviewAt,
  );

  void _validate() {
    if (_policies.isEmpty) {
      throw const FertilizerPolicyConfigurationException('Policies are empty.');
    }
    for (final entry in _policies.entries) {
      final policy = entry.value;
      if (entry.key != policy.canonicalPlantKey ||
          policy.growthStages.isEmpty ||
          policy.category == FertilizerCategory.insufficientEvidence ||
          policy.evidenceChunkIds.length < 2 ||
          policy.evidenceChunkIds.toSet().length !=
              policy.evidenceChunkIds.length ||
          policy.evidenceChunkIds.any(
            (id) =>
                !id.startsWith(
                  '${policy.canonicalPlantKey}__nutrient_guidance__',
                ) ||
                id.contains('/'),
          )) {
        throw FertilizerPolicyConfigurationException(
          'Invalid fertilizer policy for ${entry.key}.',
        );
      }
    }
  }
}
