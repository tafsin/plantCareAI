import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/plant_observation/services/firebase_ai_plant_observation_service.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_shared/environment.dart';

void main() {
  test('uses the explicit stable Gemini 3.5 Flash-Lite model', () {
    expect(FirebaseAiPlantObservationService.model, 'gemini-3.5-flash-lite');
  });

  test('uses Gemini 3-compatible generation options', () {
    final config = FirebaseAiPlantObservationService.generationConfig;

    expect(config.responseModalities, isNull);
    expect(config.thinkingConfig?.thinkingBudget, isNull);
    expect(config.thinkingConfig?.thinkingLevel, ThinkingLevel.low);
    expect(config.responseMimeType, 'application/json');
    expect(config.maxOutputTokens, 1400);
  });

  test('uses Google AI-compatible medium probability safety settings', () {
    final settings = FirebaseAiPlantObservationService.safetySettings;

    expect(settings, hasLength(4));
    expect(
      settings.map((setting) => setting.threshold),
      everyElement(HarmBlockThreshold.medium),
    );
    expect(settings.map((setting) => setting.method), everyElement(isNull));
  });

  test('does not invoke AI when the active user is signed out', () async {
    var requests = 0;
    final service = FirebaseAiPlantObservationService.forTest(
      isAuthenticated: () => false,
      generateResponse: (_, _) async {
        requests++;
        return null;
      },
      environmentConfig: const _Config(),
    );

    await expectLater(
      service.observe(image: _image, context: _context),
      throwsA(
        isA<PlantObservationFailure>().having(
          (failure) => failure.type,
          'type',
          PlantObservationFailureType.unauthenticated,
        ),
      ),
    );
    expect(requests, 0);
  });

  test('maps authentication and App Check response failures separately', () {
    expect(
      FirebaseAiPlantObservationService.mapFirebaseAiErrorMessage(
        'HTTP 401 unauthenticated',
      ).type,
      PlantObservationFailureType.unauthenticated,
    );
    expect(
      FirebaseAiPlantObservationService.mapFirebaseAiErrorMessage(
        'HTTP 403 invalid App Check token',
      ).type,
      PlantObservationFailureType.appCheckRejected,
    );
    expect(
      FirebaseAiPlantObservationService.mapFirebaseAiErrorMessage(
        'HTTP 403 permission denied',
      ).type,
      PlantObservationFailureType.permissionDenied,
    );
  });

  test('maps retired and unavailable models separately', () {
    expect(
      FirebaseAiPlantObservationService.mapFirebaseAiErrorMessage(
        'The requested model has been retired',
      ).type,
      PlantObservationFailureType.retiredModel,
    );
    expect(
      FirebaseAiPlantObservationService.mapFirebaseAiErrorMessage(
        '404 model not found',
      ).type,
      PlantObservationFailureType.modelUnavailable,
    );
  });
}

final _image = SelectedPlantImage(
  bytes: Uint8List.fromList([1, 2, 3]),
  mimeType: 'image/jpeg',
  filename: 'plant.jpg',
);

const _context = PlantObservationContext(
  commonName: 'Plant',
  environment: 'indoor',
  growthStage: 'mature',
);

final class _Config implements EnvironmentConfig {
  const _Config();

  @override
  AppEnvironment get environment => AppEnvironment.development;

  @override
  bool get isProduction => false;

  @override
  bool get useFirebaseAuthEmulator => false;

  @override
  bool get useAppCheckDebug => false;

  @override
  String? get appCheckRecaptchaEnterpriseSiteKey => null;
}
