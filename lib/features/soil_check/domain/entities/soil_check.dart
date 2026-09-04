import 'package:equatable/equatable.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

abstract final class SoilCheckVersions {
  static const schema = 1;
  static const policy = 'manual-watering-v1';
  static const source = 'deterministic_client_policy';
  static const method = 'manual_finger_test';
  static const dataset = '2026-09-03-v2';
  static const legacyDataset = '2026-09-03-v1';
}

enum SoilMoistureLevel { veryDry, dry, slightlyMoist, moist, wet }

enum WateringOutcome {
  waterNow,
  wait,
  checkAgain,
  inconsistentInput,
  unsupportedPlant,
}

extension SoilMoistureLevelValue on SoilMoistureLevel {
  String get value => switch (this) {
    SoilMoistureLevel.veryDry => 'very_dry',
    SoilMoistureLevel.dry => 'dry',
    SoilMoistureLevel.slightlyMoist => 'slightly_moist',
    SoilMoistureLevel.moist => 'moist',
    SoilMoistureLevel.wet => 'wet',
  };

  static SoilMoistureLevel parse(String value) => switch (value) {
    'very_dry' => SoilMoistureLevel.veryDry,
    'dry' => SoilMoistureLevel.dry,
    'slightly_moist' => SoilMoistureLevel.slightlyMoist,
    'moist' => SoilMoistureLevel.moist,
    'wet' => SoilMoistureLevel.wet,
    _ => throw const FormatException('Invalid soil moisture level.'),
  };
}

extension WateringOutcomeValue on WateringOutcome {
  String get value => switch (this) {
    WateringOutcome.waterNow => 'water_now',
    WateringOutcome.wait => 'wait',
    WateringOutcome.checkAgain => 'check_again',
    WateringOutcome.inconsistentInput => 'inconsistent_input',
    WateringOutcome.unsupportedPlant => 'unsupported_plant',
  };

  static WateringOutcome parse(String value) => switch (value) {
    'water_now' => WateringOutcome.waterNow,
    'wait' => WateringOutcome.wait,
    'check_again' => WateringOutcome.checkAgain,
    'inconsistent_input' => WateringOutcome.inconsistentInput,
    'unsupported_plant' => WateringOutcome.unsupportedPlant,
    _ => throw const FormatException('Invalid watering outcome.'),
  };
}

final class WateringGuidanceInput extends Equatable {
  const WateringGuidanceInput({
    required this.canonicalPlantKey,
    required this.environment,
    required this.growingMedium,
    required this.moistureLevel,
    required this.checkTime,
  });

  final String? canonicalPlantKey;
  final PlantEnvironment environment;
  final GrowingMedium growingMedium;
  final SoilMoistureLevel moistureLevel;
  final DateTime checkTime;

  @override
  List<Object?> get props => [
    canonicalPlantKey,
    environment,
    growingMedium,
    moistureLevel,
    checkTime,
  ];
}

final class WateringGuidance extends Equatable {
  const WateringGuidance({
    required this.canonicalPlantKey,
    required this.outcome,
    required this.title,
    required this.explanation,
    required this.cautions,
    required this.evidenceChunkIds,
    this.suggestedCheckAfter,
    this.schemaVersion = SoilCheckVersions.schema,
    this.policyVersion = SoilCheckVersions.policy,
    this.datasetVersion = SoilCheckVersions.dataset,
  });

  final int schemaVersion;
  final String policyVersion;
  final String datasetVersion;
  final String? canonicalPlantKey;
  final WateringOutcome outcome;
  final String title;
  final String explanation;
  final List<String> cautions;
  final List<String> evidenceChunkIds;
  final Duration? suggestedCheckAfter;

  @override
  List<Object?> get props => [
    schemaVersion,
    policyVersion,
    datasetVersion,
    canonicalPlantKey,
    outcome,
    title,
    explanation,
    cautions,
    evidenceChunkIds,
    suggestedCheckAfter,
  ];
}

final class SoilCheckRecord extends Equatable {
  const SoilCheckRecord({
    required this.id,
    required this.moistureLevel,
    required this.guidance,
    required this.environmentSnapshot,
    required this.growingMediumSnapshot,
    this.createdAt,
    this.suggestedCheckAt,
  });

  final String id;
  final SoilMoistureLevel moistureLevel;
  final WateringGuidance guidance;
  final PlantEnvironment environmentSnapshot;
  final GrowingMedium growingMediumSnapshot;
  final DateTime? createdAt;
  final DateTime? suggestedCheckAt;

  @override
  List<Object?> get props => [
    id,
    moistureLevel,
    guidance,
    environmentSnapshot,
    growingMediumSnapshot,
    createdAt,
    suggestedCheckAt,
  ];
}
