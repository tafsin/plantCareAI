import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:plantcare_app/app/verification/plant_identification_verification_override.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';

void main() {
  late GetIt container;

  setUp(() {
    container = GetIt.asNewInstance();
    container.registerSingleton<PlantIdentificationService>(_ExistingService());
  });

  tearDown(() => container.reset());

  test('empty scenario keeps the production service', () async {
    final original = container<PlantIdentificationService>();

    await installPlantIdentificationVerificationOverride(
      container,
      scenarioValue: '',
      isReleaseMode: false,
      useFirebaseAuthEmulator: true,
    );

    expect(container<PlantIdentificationService>(), same(original));
  });

  for (final entry in {
    'supported': ('Pothos', 0.92),
    'low_confidence': ('Pothos', 0.52),
    'unsupported': ('Monstera', 0.91),
  }.entries) {
    test('installs ${entry.key} response only for emulator debug', () async {
      await installPlantIdentificationVerificationOverride(
        container,
        scenarioValue: entry.key,
        isReleaseMode: false,
        useFirebaseAuthEmulator: true,
      );

      final result = await container<PlantIdentificationService>().identify(
        image: SelectedPlantImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/jpeg',
          filename: 'fixture.jpg',
        ),
      );
      expect(result.candidates.first.commonName, entry.value.$1);
      expect(result.candidates.first.confidence, entry.value.$2);
    });
  }

  test(
    'rejects verification responses in release or against live data',
    () async {
      await expectLater(
        installPlantIdentificationVerificationOverride(
          container,
          scenarioValue: 'supported',
          isReleaseMode: true,
          useFirebaseAuthEmulator: true,
        ),
        throwsStateError,
      );
      await expectLater(
        installPlantIdentificationVerificationOverride(
          container,
          scenarioValue: 'supported',
          isReleaseMode: false,
          useFirebaseAuthEmulator: false,
        ),
        throwsStateError,
      );
    },
  );
}

final class _ExistingService implements PlantIdentificationService {
  @override
  Future<PlantIdentificationResult> identify({
    required SelectedPlantImage image,
  }) => throw UnimplementedError();
}
