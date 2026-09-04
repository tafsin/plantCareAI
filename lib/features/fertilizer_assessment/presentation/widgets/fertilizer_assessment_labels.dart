import 'package:plantcare_domain/fertilizer_assessment.dart';

extension GrowthActivityLabel on GrowthActivity {
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
}

extension FertilizerCategoryLabel on FertilizerCategory {
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
}
