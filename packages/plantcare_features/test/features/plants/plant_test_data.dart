import 'package:plantcare_domain/plants.dart';

final samplePlant = Plant(
  id: 'plant-1',
  commonName: 'Monstera',
  scientificName: 'Monstera deliciosa',
  environment: PlantEnvironment.indoor,
  growingMedium: GrowingMedium.pot,
  potSizeLiters: 12,
  sunlight: Sunlight.partial,
  growthStage: GrowthStage.mature,
  notes: 'Near the window',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 2, 1),
);

const sampleDraft = PlantDraft(
  commonName: 'Monstera',
  scientificName: 'Monstera deliciosa',
  environment: PlantEnvironment.indoor,
  growingMedium: GrowingMedium.pot,
  potSizeLiters: 12,
  sunlight: Sunlight.partial,
  growthStage: GrowthStage.mature,
  notes: 'Near the window',
);
