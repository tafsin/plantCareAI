import 'package:equatable/equatable.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

abstract final class SupportedPlants {
  static const keys = {
    'tomato',
    'pumpkin',
    'pothos',
    'snake_plant',
    'peace_lily',
  };

  static const labels = {
    'tomato': 'Tomato',
    'pumpkin': 'Pumpkin',
    'pothos': 'Pothos',
    'snake_plant': 'Snake plant',
    'peace_lily': 'Peace lily',
  };
}

String normalizePlantName(String value) => value
    .replaceAll(RegExp('[\u2018\u2019\u02bc]'), "'")
    .replaceAll("'", '')
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[._,/\\()\[\]{}:;!?\-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _canonicalNames = <String, String>{
  'tomato': 'tomato',
  'solanum lycopersicum': 'tomato',
  'lycopersicon esculentum': 'tomato',
  'lycopersicon lycopersicum': 'tomato',
  'pumpkin': 'pumpkin',
  'cucurbita pepo': 'pumpkin',
  'pothos': 'pothos',
  'golden pothos': 'pothos',
  'devils ivy': 'pothos',
  'epipremnum aureum': 'pothos',
  'scindapsus aureus': 'pothos',
  'snake plant': 'snake_plant',
  'mother in laws tongue': 'snake_plant',
  'dracaena trifasciata': 'snake_plant',
  'sansevieria trifasciata': 'snake_plant',
  'peace lily': 'peace_lily',
  'spathiphyllum': 'peace_lily',
  'spathiphyllum wallisii': 'peace_lily',
};

String? canonicalPlantKeyFor(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return _canonicalNames[normalizePlantName(value)];
}

enum PlantResolutionStatus { resolved, conflict, unsupported }

final class PlantResolution extends Equatable {
  const PlantResolution._(this.status, {this.canonicalKey, this.candidates});

  const PlantResolution.resolved(String key)
    : this._(PlantResolutionStatus.resolved, canonicalKey: key);
  const PlantResolution.conflict(List<String> values)
    : this._(PlantResolutionStatus.conflict, candidates: values);
  const PlantResolution.unsupported()
    : this._(PlantResolutionStatus.unsupported);

  final PlantResolutionStatus status;
  final String? canonicalKey;
  final List<String>? candidates;

  @override
  List<Object?> get props => [status, canonicalKey, candidates];
}

final class PlantNameResolver {
  const PlantNameResolver();

  static const minimumAiConfidence = 0.70;

  PlantResolution resolve(Plant plant, PlantObservation observation) {
    final profile =
        canonicalPlantKeyFor(plant.scientificName) ??
        canonicalPlantKeyFor(plant.commonName);
    final identification = observation.possibleIdentification;
    final ai = (identification.confidence ?? 0) >= minimumAiConfidence
        ? canonicalPlantKeyFor(identification.scientificName) ??
              canonicalPlantKeyFor(identification.commonName)
        : null;

    if (profile != null && ai != null && profile != ai) {
      return PlantResolution.conflict([profile, ai]);
    }
    final resolved = profile ?? ai;
    return resolved == null
        ? const PlantResolution.unsupported()
        : PlantResolution.resolved(resolved);
  }
}
