import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart';
import 'package:plantcare_ai/app/dependency_injection/injection.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_domain/soil_check.dart';

void main() {
  tearDown(() async {
    await getIt.reset();
  });

  test('resolves the app initializer before Firebase is initialized', () async {
    await configureDependencies();

    expect(() => getIt<AppInitializer>(), returnsNormally);
  });

  test(
    'includes all data micro-package contracts in the app container',
    () async {
      await configureDependencies();

      for (final registered in [
        getIt.isRegistered<AuthenticationRepository>(),
        getIt.isRegistered<CareLogRepository>(),
        getIt.isRegistered<FertilizerAssessmentRepository>(),
        getIt.isRegistered<KnowledgeRepository>(),
        getIt.isRegistered<PlantDiagnosisRepository>(),
        getIt.isRegistered<PlantDiagnosisService>(),
        getIt.isRegistered<PlantImagePicker>(),
        getIt.isRegistered<PlantImageProcessor>(),
        getIt.isRegistered<PlantObservationRepository>(),
        getIt.isRegistered<PlantObservationService>(),
        getIt.isRegistered<PlantRepository>(),
        getIt.isRegistered<NotificationIdStore>(),
        getIt.isRegistered<NotificationScheduler>(),
        getIt.isRegistered<ReminderRepository>(),
        getIt.isRegistered<SoilCheckRepository>(),
      ]) {
        expect(registered, isTrue);
      }
    },
  );
}
