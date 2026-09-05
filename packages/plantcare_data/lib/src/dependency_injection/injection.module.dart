// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:injectable/injectable.dart' as _i526;
import 'package:plantcare_data/src/authentication/repositories/firebase_authentication_repository.dart'
    as _i903;
import 'package:plantcare_data/src/care_history/repositories/firebase_care_log_repository.dart'
    as _i146;
import 'package:plantcare_data/src/fertilizer_assessment/repositories/firebase_fertilizer_assessment_repository.dart'
    as _i942;
import 'package:plantcare_data/src/knowledge_retrieval/repositories/firebase_knowledge_repository.dart'
    as _i367;
import 'package:plantcare_data/src/plant_diagnosis/repositories/firebase_plant_diagnosis_repository.dart'
    as _i331;
import 'package:plantcare_data/src/plant_diagnosis/services/firebase_ai_plant_diagnosis_service.dart'
    as _i3;
import 'package:plantcare_data/src/plant_observation/repositories/firebase_plant_observation_repository.dart'
    as _i149;
import 'package:plantcare_data/src/plant_observation/services/firebase_ai_plant_observation_service.dart'
    as _i382;
import 'package:plantcare_data/src/plant_observation/services/image_picker_plant_image_picker.dart'
    as _i842;
import 'package:plantcare_data/src/plant_observation/services/local_plant_image_processor.dart'
    as _i490;
import 'package:plantcare_data/src/plants/repositories/firebase_plant_repository.dart'
    as _i159;
import 'package:plantcare_data/src/reminders/repositories/firebase_reminder_repository.dart'
    as _i208;
import 'package:plantcare_data/src/reminders/services/local_notification_scheduler.dart'
    as _i31;
import 'package:plantcare_data/src/reminders/services/shared_preferences_notification_id_store.dart'
    as _i381;
import 'package:plantcare_data/src/soil_check/repositories/firebase_soil_check_repository.dart'
    as _i327;
import 'package:plantcare_domain/authentication.dart' as _i521;
import 'package:plantcare_domain/care_history.dart' as _i82;
import 'package:plantcare_domain/fertilizer_assessment.dart' as _i726;
import 'package:plantcare_domain/knowledge_retrieval.dart' as _i941;
import 'package:plantcare_domain/plant_diagnosis.dart' as _i823;
import 'package:plantcare_domain/plant_observation.dart' as _i449;
import 'package:plantcare_domain/plants.dart' as _i867;
import 'package:plantcare_domain/reminders.dart' as _i412;
import 'package:plantcare_domain/soil_check.dart' as _i658;
import 'package:plantcare_shared/environment.dart' as _i515;

class PlantcareDataPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i412.NotificationIdStore>(
      () => _i381.SharedPreferencesNotificationIdStore(),
    );
    gh.lazySingleton<_i449.PlantImagePicker>(
      () => _i842.ImagePickerPlantImagePicker(),
    );
    gh.lazySingleton<_i449.PlantImageProcessor>(
      () => const _i490.LocalPlantImageProcessor(),
    );
    gh.lazySingleton<_i823.PlantDiagnosisRepository>(
      () => _i331.FirebasePlantDiagnosisRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i867.PlantRepository>(
      () => _i159.FirebasePlantRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i449.PlantObservationService>(
      () => _i382.FirebaseAiPlantObservationService(
        gh<_i59.FirebaseAuth>(),
        gh<_i515.EnvironmentConfig>(),
      ),
    );
    gh.lazySingleton<_i521.AuthenticationRepository>(
      () => _i903.FirebaseAuthenticationRepository(gh<_i59.FirebaseAuth>()),
    );
    gh.lazySingleton<_i658.SoilCheckRepository>(
      () => _i327.FirebaseSoilCheckRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i726.FertilizerAssessmentRepository>(
      () => _i942.FirebaseFertilizerAssessmentRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i823.PlantDiagnosisService>(
      () => _i3.FirebaseAiPlantDiagnosisService(
        gh<_i59.FirebaseAuth>(),
        gh<_i515.EnvironmentConfig>(),
      ),
    );
    gh.lazySingleton<_i449.PlantObservationRepository>(
      () => _i149.FirebasePlantObservationRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i82.CareLogRepository>(
      () => _i146.FirebaseCareLogRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i412.NotificationScheduler>(
      () => _i31.LocalNotificationScheduler(gh<_i412.NotificationIdStore>()),
    );
    gh.lazySingleton<_i941.KnowledgeRepository>(
      () => _i367.FirebaseKnowledgeRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i412.ReminderRepository>(
      () => _i208.FirebaseReminderRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
  }
}
