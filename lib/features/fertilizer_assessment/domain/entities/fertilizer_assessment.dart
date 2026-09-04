import 'package:equatable/equatable.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

abstract final class FertilizerAssessmentVersions {
  static const schema = 1;
  static const policy = 'deterministic-fertilizer-v1';
  static const dataset = '2026-09-03-v2';
  static const source = 'deterministic_client_policy';
}

enum GrowthActivity {
  activeGrowth,
  slowOrDormant,
  stressedOrUnhealthy,
  recentlyRepotted,
  unknown,
}

enum FertilizerOutcome {
  considerFertilizing,
  wait,
  avoidWhileStressed,
  moreInformationNeeded,
  insufficientEvidence,
  unsupportedPlant,
}

enum FertilizerCategory {
  balancedHouseplant,
  vegetableOrTomato,
  floweringOrFruiting,
  generalGarden,
  compostOrOrganicAmendment,
  insufficientEvidence,
}

extension GrowthActivityValue on GrowthActivity {
  String get value => switch (this) {
    GrowthActivity.activeGrowth => 'active_growth',
    GrowthActivity.slowOrDormant => 'slow_or_dormant',
    GrowthActivity.stressedOrUnhealthy => 'stressed_or_unhealthy',
    GrowthActivity.recentlyRepotted => 'recently_repotted',
    GrowthActivity.unknown => 'unknown',
  };

  String get label => switch (this) {
    GrowthActivity.activeGrowth => 'Active growth',
    GrowthActivity.slowOrDormant => 'Slow or dormant',
    GrowthActivity.stressedOrUnhealthy => 'Stressed or unhealthy',
    GrowthActivity.recentlyRepotted => 'Recently repotted',
    GrowthActivity.unknown => 'I’m not sure',
  };

  String get description => switch (this) {
    GrowthActivity.activeGrowth =>
      'The plant is producing new leaves, stems, flowers, or fruit.',
    GrowthActivity.slowOrDormant =>
      'Growth has naturally slowed or paused, often with shorter days.',
    GrowthActivity.stressedOrUnhealthy => 'The plant is wilted, damaged, diseased, pest-affected, or otherwise struggling.',
    GrowthActivity.recentlyRepotted =>
      'The plant was recently moved into fresh potting mix or a new container.',
    GrowthActivity.unknown =>
      'Choose this when you cannot confidently describe current growth.',
  };

  static GrowthActivity parse(String value) => switch (value) {
    'active_growth' => GrowthActivity.activeGrowth,
    'slow_or_dormant' => GrowthActivity.slowOrDormant,
    'stressed_or_unhealthy' => GrowthActivity.stressedOrUnhealthy,
    'recently_repotted' => GrowthActivity.recentlyRepotted,
    'unknown' => GrowthActivity.unknown,
    _ => throw const FormatException('Invalid growth activity.'),
  };
}

extension FertilizerOutcomeValue on FertilizerOutcome {
  String get value => switch (this) {
    FertilizerOutcome.considerFertilizing => 'consider_fertilizing',
    FertilizerOutcome.wait => 'wait',
    FertilizerOutcome.avoidWhileStressed => 'avoid_while_stressed',
    FertilizerOutcome.moreInformationNeeded => 'more_information_needed',
    FertilizerOutcome.insufficientEvidence => 'insufficient_evidence',
    FertilizerOutcome.unsupportedPlant => 'unsupported_plant',
  };

  static FertilizerOutcome parse(String value) => switch (value) {
    'consider_fertilizing' => FertilizerOutcome.considerFertilizing,
    'wait' => FertilizerOutcome.wait,
    'avoid_while_stressed' => FertilizerOutcome.avoidWhileStressed,
    'more_information_needed' => FertilizerOutcome.moreInformationNeeded,
    'insufficient_evidence' => FertilizerOutcome.insufficientEvidence,
    'unsupported_plant' => FertilizerOutcome.unsupportedPlant,
    _ => throw const FormatException('Invalid fertilizer outcome.'),
  };
}

extension FertilizerCategoryValue on FertilizerCategory {
  String get value => switch (this) {
    FertilizerCategory.balancedHouseplant => 'balanced_houseplant',
    FertilizerCategory.vegetableOrTomato => 'vegetable_or_tomato',
    FertilizerCategory.floweringOrFruiting => 'flowering_or_fruiting',
    FertilizerCategory.generalGarden => 'general_garden',
    FertilizerCategory.compostOrOrganicAmendment =>
      'compost_or_organic_amendment',
    FertilizerCategory.insufficientEvidence => 'insufficient_evidence',
  };

  String get label => switch (this) {
    FertilizerCategory.balancedHouseplant => 'Balanced houseplant fertilizer',
    FertilizerCategory.vegetableOrTomato => 'Vegetable or tomato fertilizer',
    FertilizerCategory.floweringOrFruiting =>
      'Flowering or fruiting fertilizer',
    FertilizerCategory.generalGarden => 'General garden fertilizer',
    FertilizerCategory.compostOrOrganicAmendment =>
      'Compost or organic amendment',
    FertilizerCategory.insufficientEvidence => 'Insufficient evidence',
  };

  static FertilizerCategory parse(String value) => switch (value) {
    'balanced_houseplant' => FertilizerCategory.balancedHouseplant,
    'vegetable_or_tomato' => FertilizerCategory.vegetableOrTomato,
    'flowering_or_fruiting' => FertilizerCategory.floweringOrFruiting,
    'general_garden' => FertilizerCategory.generalGarden,
    'compost_or_organic_amendment' =>
      FertilizerCategory.compostOrOrganicAmendment,
    'insufficient_evidence' => FertilizerCategory.insufficientEvidence,
    _ => throw const FormatException('Invalid fertilizer category.'),
  };
}

final class FertilizerAssessmentInput extends Equatable {
  const FertilizerAssessmentInput({
    required this.canonicalPlantKey,
    required this.environment,
    required this.growthStage,
    required this.growthActivity,
    required this.assessmentTime,
    this.lastFertilizedAt,
  });

  final String? canonicalPlantKey;
  final PlantEnvironment environment;
  final GrowthStage growthStage;
  final GrowthActivity growthActivity;
  final DateTime assessmentTime;
  final DateTime? lastFertilizedAt;

  @override
  List<Object?> get props => [
    canonicalPlantKey,
    environment,
    growthStage,
    growthActivity,
    assessmentTime,
    lastFertilizedAt,
  ];
}

final class FertilizerGuidance extends Equatable {
  const FertilizerGuidance({
    required this.canonicalPlantKey,
    required this.outcome,
    required this.title,
    required this.explanation,
    required this.cautions,
    required this.evidenceChunkIds,
    this.fertilizerCategory,
    this.lastFertilizedAt,
    this.suggestedReviewAt,
    this.schemaVersion = FertilizerAssessmentVersions.schema,
    this.policyVersion = FertilizerAssessmentVersions.policy,
    this.datasetVersion = FertilizerAssessmentVersions.dataset,
  });

  final int schemaVersion;
  final String policyVersion;
  final String datasetVersion;
  final String? canonicalPlantKey;
  final FertilizerOutcome outcome;
  final FertilizerCategory? fertilizerCategory;
  final String title;
  final String explanation;
  final List<String> cautions;
  final List<String> evidenceChunkIds;
  final DateTime? lastFertilizedAt;
  final DateTime? suggestedReviewAt;

  @override
  List<Object?> get props => [
    schemaVersion,
    policyVersion,
    datasetVersion,
    canonicalPlantKey,
    outcome,
    fertilizerCategory,
    title,
    explanation,
    cautions,
    evidenceChunkIds,
    lastFertilizedAt,
    suggestedReviewAt,
  ];
}

final class FertilizerAssessment extends Equatable {
  const FertilizerAssessment({
    required this.id,
    required this.growthActivity,
    required this.growthStageSnapshot,
    required this.environmentSnapshot,
    required this.guidance,
    this.createdAt,
  });

  final String id;
  final GrowthActivity growthActivity;
  final GrowthStage growthStageSnapshot;
  final PlantEnvironment environmentSnapshot;
  final FertilizerGuidance guidance;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
    id,
    growthActivity,
    growthStageSnapshot,
    environmentSnapshot,
    guidance,
    createdAt,
  ];
}
