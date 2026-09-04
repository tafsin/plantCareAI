import 'package:equatable/equatable.dart';

enum ObservationSeverity { none, mild, moderate, severe, unclear }

enum ObservationIssue {
  blurred,
  dark,
  overexposed,
  tooDistant,
  obstructed,
  multiplePlants,
  lowResolution,
  other,
}

enum AffectedPlantPart { leaf, stem, flower, fruit, root, wholePlant, unknown }

enum VisualObservationType {
  yellowing,
  browning,
  spots,
  lesions,
  curling,
  wilting,
  holes,
  residue,
  webbing,
  insects,
  moldLikeGrowth,
  physicalDamage,
  discoloration,
  other,
}

final class ImageQuality extends Equatable {
  const ImageQuality({required this.usable, required this.issues});

  final bool usable;
  final List<ObservationIssue> issues;

  @override
  List<Object?> get props => [usable, issues];
}

final class PossiblePlantIdentification extends Equatable {
  const PossiblePlantIdentification({
    this.commonName,
    this.scientificName,
    this.confidence,
  });

  final String? commonName;
  final String? scientificName;
  final double? confidence;

  @override
  List<Object?> get props => [commonName, scientificName, confidence];
}

final class VisibleObservation extends Equatable {
  const VisibleObservation({
    required this.type,
    required this.description,
    required this.confidence,
  });

  final VisualObservationType type;
  final String description;
  final double confidence;

  @override
  List<Object?> get props => [type, description, confidence];
}

final class ObservationFollowUp extends Equatable {
  const ObservationFollowUp({
    required this.anotherPhotoHelpful,
    this.instruction,
  });

  final bool anotherPhotoHelpful;
  final String? instruction;

  @override
  List<Object?> get props => [anotherPhotoHelpful, instruction];
}

final class PlantObservation extends Equatable {
  const PlantObservation({
    required this.schemaVersion,
    required this.plantVisible,
    required this.imageQuality,
    required this.possibleIdentification,
    required this.affectedParts,
    required this.observations,
    required this.distribution,
    required this.severity,
    required this.followUp,
    this.id = '',
    this.modelName,
    this.createdAt,
  });

  static const currentSchemaVersion = 1;

  final String id;
  final int schemaVersion;
  final bool plantVisible;
  final ImageQuality imageQuality;
  final PossiblePlantIdentification possibleIdentification;
  final List<AffectedPlantPart> affectedParts;
  final List<VisibleObservation> observations;
  final String distribution;
  final ObservationSeverity severity;
  final ObservationFollowUp followUp;
  final String? modelName;
  final DateTime? createdAt;

  PlantObservation copyWith({
    String? id,
    String? modelName,
    DateTime? createdAt,
  }) {
    return PlantObservation(
      id: id ?? this.id,
      schemaVersion: schemaVersion,
      plantVisible: plantVisible,
      imageQuality: imageQuality,
      possibleIdentification: possibleIdentification,
      affectedParts: affectedParts,
      observations: observations,
      distribution: distribution,
      severity: severity,
      followUp: followUp,
      modelName: modelName ?? this.modelName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get summary => observations.isEmpty
      ? (plantVisible
            ? 'No specific visual issue recorded.'
            : 'No plant visible.')
      : observations.first.description;

  @override
  List<Object?> get props => [
    id,
    schemaVersion,
    plantVisible,
    imageQuality,
    possibleIdentification,
    affectedParts,
    observations,
    distribution,
    severity,
    followUp,
    modelName,
    createdAt,
  ];
}

final class PlantObservationContext extends Equatable {
  const PlantObservationContext({
    required this.commonName,
    required this.environment,
    required this.growthStage,
    this.scientificName,
  });

  final String commonName;
  final String? scientificName;
  final String environment;
  final String growthStage;

  @override
  List<Object?> get props => [
    commonName,
    scientificName,
    environment,
    growthStage,
  ];
}
