import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';

const _scenarioDefine = String.fromEnvironment(
  'PLANT_IDENTIFICATION_VERIFICATION_SCENARIO',
);

enum PlantIdentificationVerificationScenario {
  supported,
  lowConfidence,
  unsupported;

  static PlantIdentificationVerificationScenario? parse(String value) =>
      switch (value) {
        '' => null,
        'supported' => supported,
        'low_confidence' => lowConfidence,
        'unsupported' => unsupported,
        _ => throw ArgumentError.value(
          value,
          'PLANT_IDENTIFICATION_VERIFICATION_SCENARIO',
          'Expected supported, low_confidence, or unsupported.',
        ),
      };
}

Future<void> installPlantIdentificationVerificationOverride(
  GetIt container, {
  String scenarioValue = _scenarioDefine,
  bool isReleaseMode = kReleaseMode,
  required bool useFirebaseAuthEmulator,
}) async {
  final scenario = PlantIdentificationVerificationScenario.parse(
    scenarioValue.trim(),
  );
  if (scenario == null) return;
  if (isReleaseMode) {
    throw StateError(
      'Plant identification verification responses are forbidden in release builds.',
    );
  }
  if (!useFirebaseAuthEmulator) {
    throw StateError(
      'Plant identification verification requires the Firebase emulators.',
    );
  }
  if (container.isRegistered<PlantIdentificationService>()) {
    await container.unregister<PlantIdentificationService>();
  }
  container.registerLazySingleton<PlantIdentificationService>(
    () => _VerificationPlantIdentificationService(scenario),
  );
}

final class _VerificationPlantIdentificationService
    implements PlantIdentificationService {
  _VerificationPlantIdentificationService(this._scenario);

  final PlantIdentificationVerificationScenario _scenario;
  var _requestCount = 0;

  @override
  Future<PlantIdentificationResult> identify({
    required SelectedPlantImage image,
  }) async {
    _requestCount++;
    if (kDebugMode) {
      developer.log(
        'scenario=${_scenario.name} requestCount=$_requestCount '
        'mimeType=${image.mimeType} byteCount=${image.bytes.length}',
        name: 'plantcare_ai.identification_verification',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return switch (_scenario) {
      PlantIdentificationVerificationScenario.supported =>
        PlantIdentificationResult(
          imageStatus: IdentificationImageStatus.usableImage,
          candidates: [
            PlantIdentificationCandidate(
              commonName: 'Pothos',
              scientificName: 'Epipremnum aureum',
              confidence: 0.92,
              visibleEvidence: const [
                'Heart-shaped green leaves',
                'Trailing vine growth',
              ],
              ambiguityNote:
                  'Leaf pattern can overlap with similar climbing aroids.',
            ),
            PlantIdentificationCandidate(
              commonName: 'Peace Lily',
              scientificName: 'Spathiphyllum wallisii',
              confidence: 0.66,
              visibleEvidence: const ['Glossy green leaves'],
              ambiguityNote: 'No flower is visible for comparison.',
            ),
          ],
        ),
      PlantIdentificationVerificationScenario.lowConfidence =>
        PlantIdentificationResult(
          imageStatus: IdentificationImageStatus.usableImage,
          candidates: [
            PlantIdentificationCandidate(
              commonName: 'Pothos',
              scientificName: 'Epipremnum aureum',
              confidence: 0.52,
              visibleEvidence: const ['Green leaves are partly visible'],
              ambiguityNote: 'The visible features are not distinctive.',
            ),
            PlantIdentificationCandidate(
              commonName: 'Peace Lily',
              scientificName: 'Spathiphyllum wallisii',
              confidence: 0.41,
              visibleEvidence: const ['Broad green leaf shape'],
              ambiguityNote: 'The image does not show enough detail.',
            ),
          ],
        ),
      PlantIdentificationVerificationScenario.unsupported =>
        PlantIdentificationResult(
          imageStatus: IdentificationImageStatus.usableImage,
          candidates: [
            PlantIdentificationCandidate(
              commonName: 'Monstera',
              scientificName: 'Monstera deliciosa',
              confidence: 0.91,
              visibleEvidence: const [
                'Large split leaves',
                'Fenestrations visible in mature foliage',
              ],
              ambiguityNote:
                  'Confirmation should use the whole plant and mature leaves.',
            ),
          ],
        ),
    };
  }
}
