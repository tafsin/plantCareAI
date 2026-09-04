import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

extension PlantEnvironmentLabel on PlantEnvironment {
  String get label => switch (this) {
    PlantEnvironment.indoor => 'Indoor',
    PlantEnvironment.outdoor => 'Outdoor',
  };
}

extension GrowingMediumLabel on GrowingMedium {
  String get label => switch (this) {
    GrowingMedium.pot => 'Pot',
    GrowingMedium.ground => 'Ground',
  };
}

extension SunlightLabel on Sunlight {
  String get label => switch (this) {
    Sunlight.low => 'Low light',
    Sunlight.partial => 'Partial sun',
    Sunlight.full => 'Full sun',
  };
}

extension GrowthStageLabel on GrowthStage {
  String get label => switch (this) {
    GrowthStage.seedling => 'Seedling',
    GrowthStage.vegetative => 'Vegetative',
    GrowthStage.flowering => 'Flowering',
    GrowthStage.fruiting => 'Fruiting',
    GrowthStage.mature => 'Mature',
  };
}

String plantDateLabel(DateTime? value) {
  if (value == null) return 'Saving…';
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
