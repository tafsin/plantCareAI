// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:get_it/get_it.dart' as _i174;
import 'package:go_router/go_router.dart' as _i583;
import 'package:injectable/injectable.dart' as _i526;
import 'package:plantcare_ai/app/application/reminder_lifecycle_service.dart'
    as _i200;
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart' as _i963;
import 'package:plantcare_ai/app/bootstrap/firebase_app_check_activator.dart'
    as _i342;
import 'package:plantcare_ai/app/dependency_injection/app_module.dart'
    as _i1018;
import 'package:plantcare_ai/app/theme/theme_bloc.dart' as _i973;
import 'package:plantcare_ai/features/authentication/data/repositories/firebase_authentication_repository.dart'
    as _i406;
import 'package:plantcare_ai/features/authentication/presentation/bloc/auth_session_bloc.dart'
    as _i2;
import 'package:plantcare_ai/features/authentication/presentation/bloc/authentication_bloc_factory.dart'
    as _i1017;
import 'package:plantcare_ai/features/care_history/data/repositories/firebase_care_log_repository.dart'
    as _i729;
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_bloc_factory.dart'
    as _i139;
import 'package:plantcare_ai/features/fertilizer_assessment/data/repositories/firebase_fertilizer_assessment_repository.dart'
    as _i863;
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_bloc_factory.dart'
    as _i970;
import 'package:plantcare_ai/features/knowledge_retrieval/data/repositories/firebase_knowledge_repository.dart'
    as _i1064;
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc_factory.dart'
    as _i1029;
import 'package:plantcare_ai/features/plant_diagnosis/data/repositories/firebase_plant_diagnosis_repository.dart'
    as _i976;
import 'package:plantcare_ai/features/plant_diagnosis/data/services/firebase_ai_plant_diagnosis_service.dart'
    as _i796;
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/plant_diagnosis_bloc_factory.dart'
    as _i1;
import 'package:plantcare_ai/features/plant_observation/data/repositories/firebase_plant_observation_repository.dart'
    as _i177;
import 'package:plantcare_ai/features/plant_observation/data/services/firebase_ai_plant_observation_service.dart'
    as _i359;
import 'package:plantcare_ai/features/plant_observation/data/services/image_picker_plant_image_picker.dart'
    as _i533;
import 'package:plantcare_ai/features/plant_observation/data/services/local_plant_image_processor.dart'
    as _i491;
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/plant_observation_bloc_factory.dart'
    as _i641;
import 'package:plantcare_ai/features/plants/data/repositories/firebase_plant_repository.dart'
    as _i78;
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_bloc_factory.dart'
    as _i964;
import 'package:plantcare_ai/features/reminders/data/repositories/firebase_reminder_repository.dart'
    as _i420;
import 'package:plantcare_ai/features/reminders/data/services/local_notification_scheduler.dart'
    as _i176;
import 'package:plantcare_ai/features/reminders/data/services/shared_preferences_notification_id_store.dart'
    as _i985;
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminder_bloc_factory.dart'
    as _i208;
import 'package:plantcare_ai/features/soil_check/data/repositories/firebase_soil_check_repository.dart'
    as _i949;
import 'package:plantcare_ai/features/soil_check/presentation/bloc/soil_check_bloc_factory.dart'
    as _i727;
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

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    gh.factory<_i973.ThemeBloc>(() => _i973.ThemeBloc());
    gh.lazySingleton<_i59.FirebaseAuth>(() => appModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(
      () => appModule.firebaseFirestore,
    );
    gh.lazySingleton<_i515.EnvironmentConfig>(
      () => appModule.environmentConfig,
    );
    gh.lazySingleton<_i449.PlantImagePicker>(
      () => _i533.ImagePickerPlantImagePicker(),
    );
    gh.lazySingleton<_i449.PlantImageProcessor>(
      () => const _i491.LocalPlantImageProcessor(),
    );
    gh.lazySingleton<_i412.NotificationIdStore>(
      () => _i985.SharedPreferencesNotificationIdStore(),
    );
    gh.lazySingleton<_i342.FirebaseAppCheckActivator>(
      () => appModule.firebaseAppCheckActivator(gh<_i515.EnvironmentConfig>()),
    );
    gh.lazySingleton<_i449.PlantObservationService>(
      () => _i359.FirebaseAiPlantObservationService(
        gh<_i59.FirebaseAuth>(),
        gh<_i515.EnvironmentConfig>(),
      ),
    );
    gh.lazySingleton<_i726.FertilizerAssessmentRepository>(
      () => _i863.FirebaseFertilizerAssessmentRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i658.SoilCheckRepository>(
      () => _i949.FirebaseSoilCheckRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i963.AppInitializer>(
      () => appModule.appInitializer(
        gh<_i515.EnvironmentConfig>(),
        gh<_i342.FirebaseAppCheckActivator>(),
      ),
    );
    gh.lazySingleton<_i823.PlantDiagnosisService>(
      () => _i796.FirebaseAiPlantDiagnosisService(
        gh<_i59.FirebaseAuth>(),
        gh<_i515.EnvironmentConfig>(),
      ),
    );
    gh.lazySingleton<_i823.PlantDiagnosisRepository>(
      () => _i976.FirebasePlantDiagnosisRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i449.PlantObservationRepository>(
      () => _i177.FirebasePlantObservationRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i941.KnowledgeRepository>(
      () => _i1064.FirebaseKnowledgeRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i867.PlantRepository>(
      () => _i78.FirebasePlantRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i82.CareLogRepository>(
      () => _i729.FirebaseCareLogRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i727.SoilCheckBlocFactory>(
      () => _i727.SoilCheckBlocFactory(
        gh<_i867.PlantRepository>(),
        gh<_i658.SoilCheckRepository>(),
        gh<_i941.KnowledgeRepository>(),
      ),
    );
    gh.lazySingleton<_i521.AuthenticationRepository>(
      () => _i406.FirebaseAuthenticationRepository(gh<_i59.FirebaseAuth>()),
    );
    gh.lazySingleton<_i412.ReminderRepository>(
      () => _i420.FirebaseReminderRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i412.NotificationScheduler>(
      () => _i176.LocalNotificationScheduler(gh<_i412.NotificationIdStore>()),
    );
    gh.lazySingleton<_i2.AuthSessionBloc>(
      () => _i2.AuthSessionBloc(gh<_i521.AuthenticationRepository>()),
    );
    gh.lazySingleton<_i1017.AuthenticationBlocFactory>(
      () => _i1017.AuthenticationBlocFactory(
        gh<_i521.AuthenticationRepository>(),
      ),
    );
    gh.lazySingleton<_i970.FertilizerAssessmentBlocFactory>(
      () => _i970.FertilizerAssessmentBlocFactory(
        gh<_i867.PlantRepository>(),
        gh<_i82.CareLogRepository>(),
        gh<_i726.FertilizerAssessmentRepository>(),
        gh<_i941.KnowledgeRepository>(),
      ),
    );
    gh.lazySingleton<_i1029.KnowledgeRetrievalBlocFactory>(
      () =>
          _i1029.KnowledgeRetrievalBlocFactory(gh<_i941.KnowledgeRepository>()),
    );
    gh.lazySingleton<_i139.CareLogBlocFactory>(
      () => _i139.CareLogBlocFactory(gh<_i82.CareLogRepository>()),
    );
    gh.lazySingleton<_i1.PlantDiagnosisBlocFactory>(
      () => _i1.PlantDiagnosisBlocFactory(
        gh<_i941.KnowledgeRepository>(),
        gh<_i823.PlantDiagnosisRepository>(),
        gh<_i823.PlantDiagnosisService>(),
      ),
    );
    gh.lazySingleton<_i641.PlantObservationBlocFactory>(
      () => _i641.PlantObservationBlocFactory(
        gh<_i449.PlantImagePicker>(),
        gh<_i449.PlantImageProcessor>(),
        gh<_i449.PlantObservationService>(),
        gh<_i449.PlantObservationRepository>(),
      ),
    );
    gh.lazySingleton<_i964.PlantBlocFactory>(
      () => _i964.PlantBlocFactory(gh<_i867.PlantRepository>()),
    );
    gh.lazySingleton<_i521.AuthenticationSession>(
      () =>
          appModule.authenticationSession(gh<_i521.AuthenticationRepository>()),
    );
    gh.lazySingleton<_i208.ReminderBlocFactory>(
      () => _i208.ReminderBlocFactory(
        gh<_i412.ReminderRepository>(),
        gh<_i412.NotificationScheduler>(),
        gh<_i521.AuthenticationSession>(),
      ),
    );
    gh.lazySingleton<_i583.GoRouter>(
      () => appModule.router(
        gh<_i2.AuthSessionBloc>(),
        gh<_i1017.AuthenticationBlocFactory>(),
        gh<_i964.PlantBlocFactory>(),
        gh<_i641.PlantObservationBlocFactory>(),
        gh<_i1029.KnowledgeRetrievalBlocFactory>(),
        gh<_i1.PlantDiagnosisBlocFactory>(),
        gh<_i727.SoilCheckBlocFactory>(),
        gh<_i139.CareLogBlocFactory>(),
        gh<_i970.FertilizerAssessmentBlocFactory>(),
        gh<_i208.ReminderBlocFactory>(),
      ),
    );
    gh.lazySingleton<_i200.ReminderLifecycleService>(
      () => _i200.ReminderLifecycleService(
        gh<_i521.AuthenticationSession>(),
        gh<_i412.ReminderRepository>(),
        gh<_i867.PlantRepository>(),
        gh<_i412.NotificationScheduler>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i1018.AppModule {}
