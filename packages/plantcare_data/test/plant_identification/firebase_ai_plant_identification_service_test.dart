import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/plant_identification/firebase_ai_plant_identification_service.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';

void main() {
  final image = SelectedPlantImage(
    bytes: Uint8List.fromList([1]),
    mimeType: 'image/jpeg',
    filename: 'not-transmitted.jpg',
  );
  test('requires signed-in user before calling AI', () async {
    var calls = 0;
    final service = FirebaseAiPlantIdentificationService.forTest(
      isAuthenticated: () => false,
      generateResponse: (_) async {
        calls++;
        return null;
      },
    );
    await expectLater(
      service.identify(image: image),
      throwsA(
        isA<PlantIdentificationFailure>().having(
          (f) => f.type,
          'type',
          PlantIdentificationFailureType.unauthenticated,
        ),
      ),
    );
    expect(calls, 0);
  });
  test('decodes response and rejects malformed response', () async {
    String? response =
        '{"schemaVersion":1,"imageStatus":"no_plant_visible","identification_candidates":[]}';
    final service = FirebaseAiPlantIdentificationService.forTest(
      isAuthenticated: () => true,
      generateResponse: (_) async => response,
    );
    expect(
      (await service.identify(image: image)).imageStatus,
      IdentificationImageStatus.noPlantVisible,
    );
    for (final bad in [null, '{}', 'not JSON']) {
      response = bad;
      await expectLater(
        service.identify(image: image),
        throwsA(
          isA<PlantIdentificationFailure>().having(
            (f) => f.type,
            'type',
            PlantIdentificationFailureType.malformed,
          ),
        ),
      );
    }
  });
  test('drops result if authentication changes in flight', () async {
    var signedIn = true;
    final service = FirebaseAiPlantIdentificationService.forTest(
      isAuthenticated: () => signedIn,
      generateResponse: (_) async {
        signedIn = false;
        return '{"schemaVersion":1,"imageStatus":"no_plant_visible","identification_candidates":[]}';
      },
    );
    await expectLater(
      service.identify(image: image),
      throwsA(isA<PlantIdentificationFailure>()),
    );
  });
  final errors = {
    'quota exceeded 429': PlantIdentificationFailureType.quota,
    'network timeout': PlantIdentificationFailureType.network,
    'App Check rejected': PlantIdentificationFailureType.appCheck,
    'blocked by safety': PlantIdentificationFailureType.safety,
    '401 unauthenticated': PlantIdentificationFailureType.unauthenticated,
    '403 denied': PlantIdentificationFailureType.unavailable,
  };
  for (final entry in errors.entries) {
    test('maps ${entry.key} safely', () async {
      final service = FirebaseAiPlantIdentificationService.forTest(
        isAuthenticated: () => true,
        generateResponse: (_) async => throw FirebaseAIException(entry.key),
      );
      await expectLater(
        service.identify(image: image),
        throwsA(
          isA<PlantIdentificationFailure>().having(
            (f) => f.type,
            'type',
            entry.value,
          ),
        ),
      );
    });
  }
}
