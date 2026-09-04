import 'package:equatable/equatable.dart';

enum PlantEnvironment { indoor, outdoor }

enum GrowingMedium { pot, ground }

enum Sunlight { low, partial, full }

enum GrowthStage { seedling, vegetative, flowering, fruiting, mature }

final class Plant extends Equatable {
  const Plant({
    required this.id,
    required this.commonName,
    required this.environment,
    required this.growingMedium,
    required this.sunlight,
    required this.growthStage,
    this.scientificName,
    this.potSizeLiters,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String commonName;
  final String? scientificName;
  final PlantEnvironment environment;
  final GrowingMedium growingMedium;
  final double? potSizeLiters;
  final Sunlight sunlight;
  final GrowthStage growthStage;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    commonName,
    scientificName,
    environment,
    growingMedium,
    potSizeLiters,
    sunlight,
    growthStage,
    notes,
    createdAt,
    updatedAt,
  ];
}

final class PlantDraft extends Equatable {
  const PlantDraft({
    required this.commonName,
    required this.environment,
    required this.growingMedium,
    required this.sunlight,
    required this.growthStage,
    this.scientificName,
    this.potSizeLiters,
    this.notes,
  });

  factory PlantDraft.fromPlant(Plant plant) => PlantDraft(
    commonName: plant.commonName,
    scientificName: plant.scientificName,
    environment: plant.environment,
    growingMedium: plant.growingMedium,
    potSizeLiters: plant.potSizeLiters,
    sunlight: plant.sunlight,
    growthStage: plant.growthStage,
    notes: plant.notes,
  );

  final String commonName;
  final String? scientificName;
  final PlantEnvironment environment;
  final GrowingMedium growingMedium;
  final double? potSizeLiters;
  final Sunlight sunlight;
  final GrowthStage growthStage;
  final String? notes;

  PlantDraft normalized() => PlantDraft(
    commonName: commonName.trim(),
    scientificName: _trimmedOrNull(scientificName),
    environment: environment,
    growingMedium: growingMedium,
    potSizeLiters: growingMedium == GrowingMedium.pot ? potSizeLiters : null,
    sunlight: sunlight,
    growthStage: growthStage,
    notes: _trimmedOrNull(notes),
  );

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    commonName,
    scientificName,
    environment,
    growingMedium,
    potSizeLiters,
    sunlight,
    growthStage,
    notes,
  ];
}
