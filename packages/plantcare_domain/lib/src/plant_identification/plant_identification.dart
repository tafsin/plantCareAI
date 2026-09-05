import 'package:equatable/equatable.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_shared/errors.dart';

enum IdentificationImageStatus {
  usableImage('usable_image'),
  noPlantVisible('no_plant_visible'),
  insufficientImageQuality('insufficient_image_quality');

  const IdentificationImageStatus(this.wireValue);
  final String wireValue;
}

enum IdentificationConfidence { high, medium, low }

final class PlantIdentificationCandidate extends Equatable {
  PlantIdentificationCandidate({
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required List<String> visibleEvidence,
    this.ambiguityNote,
  }) : visibleEvidence = List.unmodifiable(visibleEvidence) {
    IdentificationText.validate(commonName, 80, botanicalName: true);
    IdentificationText.validate(scientificName, 120, botanicalName: true);
    if (!confidence.isFinite ||
        confidence < 0 ||
        confidence > 1 ||
        visibleEvidence.isEmpty ||
        visibleEvidence.length > 4) {
      throw const FormatException('Invalid candidate.');
    }
    for (final evidence in visibleEvidence) {
      IdentificationText.validate(evidence, 160);
    }
    if (ambiguityNote != null) IdentificationText.validate(ambiguityNote!, 200);
  }

  final String commonName;
  final String scientificName;
  final double confidence;
  final List<String> visibleEvidence;
  final String? ambiguityNote;

  @override
  List<Object?> get props => [
    commonName,
    scientificName,
    confidence,
    visibleEvidence,
    ambiguityNote,
  ];
}

final class PlantIdentificationResult extends Equatable {
  PlantIdentificationResult({
    required this.imageStatus,
    required List<PlantIdentificationCandidate> candidates,
    this.schemaVersion = 1,
  }) : candidates = List.unmodifiable(
         [...candidates]..sort((a, b) => b.confidence.compareTo(a.confidence)),
       ) {
    if (schemaVersion != 1 ||
        candidates.length > 3 ||
        (imageStatus != IdentificationImageStatus.usableImage &&
            candidates.isNotEmpty)) {
      throw const FormatException('Invalid identification result.');
    }
  }
  final int schemaVersion;
  final IdentificationImageStatus imageStatus;
  final List<PlantIdentificationCandidate> candidates;

  // Presentation thresholds, not calibrated probabilities or guarantees.
  IdentificationConfidence get confidence =>
      candidates.isEmpty || candidates.first.confidence < 0.60
      ? IdentificationConfidence.low
      : candidates.first.confidence >= 0.85
      ? IdentificationConfidence.high
      : IdentificationConfidence.medium;

  @override
  List<Object?> get props => [schemaVersion, imageStatus, candidates];
}

abstract final class IdentificationText {
  static void validate(
    String value,
    int maxLength, {
    bool botanicalName = false,
  }) {
    if (value.isEmpty ||
        value != value.trim() ||
        value.length > maxLength ||
        RegExp(
          r'[<>\[\]{}*_`#%\x00-\x1f\x7f]|(?:https?:|mailto:|data:|javascript:|www\.|\b\w+://)|\b(?:[a-z0-9-]+\.)+[a-z]{2,}\b|\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b|\bpercent(?:age)?\b',
          caseSensitive: false,
        ).hasMatch(value) ||
        (!botanicalName &&
            RegExp(
              r'\b(water(?:ing)?|fertiliz\w*|fertilis\w*|treat(?:ment)?|pesticide|fungicide|diagnos\w*|dosage)\b',
              caseSensitive: false,
            ).hasMatch(value))) {
      throw const FormatException('Invalid identification text.');
    }
  }
}

abstract interface class PlantIdentificationService {
  Future<PlantIdentificationResult> identify({
    required SelectedPlantImage image,
  });
}

enum PlantIdentificationFailureType {
  unauthenticated,
  quota,
  network,
  appCheck,
  safety,
  malformed,
  unavailable,
  unknown,
}

final class PlantIdentificationFailure extends AppError {
  const PlantIdentificationFailure(this.type, super.message);
  final PlantIdentificationFailureType type;
  @override
  List<Object?> get props => [type, message];
}

abstract final class OnboardingPlantSupport {
  static const limitedGuidanceMessage =
      'Plant identification is available, but detailed PlantCare guidance is currently limited for this plant.';

  static bool isSupported(String commonName, String? scientificName) {
    final common = canonicalPlantKeyFor(commonName);
    final scientific = canonicalPlantKeyFor(scientificName);
    if (scientificName != null &&
        scientificName.trim().isNotEmpty &&
        scientific == null) {
      return false;
    }
    return (common != null || scientific != null) &&
        (common == null || scientific == null || common == scientific);
  }

  static bool hasNameConflict(String commonName, String? scientificName) {
    final common = canonicalPlantKeyFor(commonName);
    final scientific = canonicalPlantKeyFor(scientificName);
    return common != null && scientific != null && common != scientific;
  }
}
