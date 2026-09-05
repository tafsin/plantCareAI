import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_app/app/application/reminder_lifecycle_service.dart';
import 'package:plantcare_app/app/bootstrap/app_initializer.dart';
import 'package:plantcare_app/app/bootstrap/firebase_app_check_activator.dart';
import 'package:plantcare_app/app/dependency_injection/injection.dart';
import 'package:plantcare_app/app/theme/theme_bloc.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_domain/soil_check.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/care_history.dart';
import 'package:plantcare_features/fertilizer_assessment.dart';
import 'package:plantcare_features/knowledge_retrieval.dart';
import 'package:plantcare_features/plant_diagnosis.dart';
import 'package:plantcare_features/plant_identification.dart';
import 'package:plantcare_features/plant_observation.dart';
import 'package:plantcare_features/plants.dart';
import 'package:plantcare_features/reminders.dart';
import 'package:plantcare_features/soil_check.dart';
import 'package:plantcare_shared/environment.dart';

void main() {
  tearDown(() async {
    await getIt.reset();
  });

  test('resolves the app initializer before Firebase is initialized', () async {
    await configureDependencies();

    final first = getIt<AppInitializer>();
    final second = getIt<AppInitializer>();

    expect(identical(first, second), isTrue);
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
        getIt.isRegistered<PlantIdentificationService>(),
        getIt.isRegistered<NotificationIdStore>(),
        getIt.isRegistered<NotificationScheduler>(),
        getIt.isRegistered<ReminderRepository>(),
        getIt.isRegistered<SoilCheckRepository>(),
      ]) {
        expect(registered, isTrue);
      }
    },
  );

  test(
    'preserves final graph registration lifetimes without duplicates',
    () async {
      await configureDependencies();

      void expectLazy<T extends Object>() {
        final registration = getIt.findFirstObjectRegistration<T>();
        expect(registration, isNotNull, reason: '$T is not registered');
        expect(registration!.registrationType, ObjectRegistrationType.lazy);
      }

      expectLazy<FirebaseAuth>();
      expectLazy<FirebaseFirestore>();
      expectLazy<EnvironmentConfig>();
      expectLazy<FirebaseAppCheckActivator>();
      expectLazy<GoRouter>();
      expectLazy<AppInitializer>();
      expectLazy<AuthenticationSession>();
      expectLazy<ReminderLifecycleService>();
      expectLazy<AuthenticationRepository>();
      expectLazy<CareLogRepository>();
      expectLazy<FertilizerAssessmentRepository>();
      expectLazy<KnowledgeRepository>();
      expectLazy<PlantDiagnosisRepository>();
      expectLazy<PlantDiagnosisService>();
      expectLazy<PlantImagePicker>();
      expectLazy<PlantImageProcessor>();
      expectLazy<PlantObservationRepository>();
      expectLazy<PlantObservationService>();
      expectLazy<PlantRepository>();
      expectLazy<PlantIdentificationService>();
      expectLazy<PlantIdentificationBlocFactory>();
      expectLazy<NotificationIdStore>();
      expectLazy<NotificationScheduler>();
      expectLazy<ReminderRepository>();
      expectLazy<SoilCheckRepository>();
      expectLazy<AuthSessionBloc>();
      expectLazy<AuthenticationBlocFactory>();
      expectLazy<CareLogBlocFactory>();
      expectLazy<FertilizerAssessmentBlocFactory>();
      expectLazy<KnowledgeRetrievalBlocFactory>();
      expectLazy<PlantDiagnosisBlocFactory>();
      expectLazy<PlantObservationBlocFactory>();
      expectLazy<PlantBlocFactory>();
      expectLazy<ReminderBlocFactory>();
      expectLazy<SoilCheckBlocFactory>();

      final themeRegistration = getIt.findFirstObjectRegistration<ThemeBloc>();
      expect(themeRegistration, isNotNull);
      expect(
        themeRegistration!.registrationType,
        ObjectRegistrationType.alwaysNew,
      );
    },
  );
}
