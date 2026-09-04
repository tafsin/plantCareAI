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
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart' as _i964;
import 'package:plantcare_ai/app/bootstrap/firebase_app_check_activator.dart'
    as _i342;
import 'package:plantcare_ai/app/dependency_injection/app_module.dart'
    as _i1018;
import 'package:plantcare_ai/app/theme/theme_bloc.dart' as _i973;
import 'package:plantcare_ai/core/utils/environment_config.dart' as _i852;
import 'package:plantcare_ai/features/authentication/data/repositories/firebase_authentication_repository.dart'
    as _i406;
import 'package:plantcare_ai/features/authentication/domain/repositories/authentication_repository.dart'
    as _i154;
import 'package:plantcare_ai/features/authentication/presentation/bloc/auth_session_bloc.dart'
    as _i2;
import 'package:plantcare_ai/features/authentication/presentation/bloc/authentication_bloc_factory.dart'
    as _i1017;
import 'package:plantcare_ai/features/care_history/data/repositories/firebase_care_log_repository.dart'
    as _i729;
import 'package:plantcare_ai/features/care_history/domain/repositories/care_log_repository.dart'
    as _i972;
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_bloc_factory.dart'
    as _i139;
import 'package:plantcare_ai/features/fertilizer_assessment/data/repositories/firebase_fertilizer_assessment_repository.dart'
    as _i863;
import 'package:plantcare_ai/features/fertilizer_assessment/domain/repositories/fertilizer_assessment_repository.dart'
    as _i304;
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_bloc_factory.dart'
    as _i970;
import 'package:plantcare_ai/features/knowledge_retrieval/data/repositories/firebase_knowledge_repository.dart'
    as _i1064;
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart'
    as _i819;
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc_factory.dart'
    as _i1029;
import 'package:plantcare_ai/features/plant_diagnosis/data/repositories/firebase_plant_diagnosis_repository.dart'
    as _i976;
import 'package:plantcare_ai/features/plant_diagnosis/data/services/firebase_ai_plant_diagnosis_service.dart'
    as _i796;
import 'package:plantcare_ai/features/plant_diagnosis/domain/repositories/plant_diagnosis_repository.dart'
    as _i687;
import 'package:plantcare_ai/features/plant_diagnosis/domain/services/plant_diagnosis_service.dart'
    as _i376;
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
import 'package:plantcare_ai/features/plant_observation/domain/repositories/plant_observation_repository.dart'
    as _i210;
import 'package:plantcare_ai/features/plant_observation/domain/services/plant_image_picker.dart'
    as _i805;
import 'package:plantcare_ai/features/plant_observation/domain/services/plant_image_processor.dart'
    as _i807;
import 'package:plantcare_ai/features/plant_observation/domain/services/plant_observation_service.dart'
    as _i519;
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/plant_observation_bloc_factory.dart'
    as _i641;
import 'package:plantcare_ai/features/plants/data/repositories/firebase_plant_repository.dart'
    as _i78;
import 'package:plantcare_ai/features/plants/domain/repositories/plant_repository.dart'
    as _i879;
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_bloc_factory.dart'
    as _i963;
import 'package:plantcare_ai/features/reminders/data/repositories/firebase_reminder_repository.dart'
    as _i420;
import 'package:plantcare_ai/features/reminders/data/services/local_notification_scheduler.dart'
    as _i176;
import 'package:plantcare_ai/features/reminders/data/services/reminder_lifecycle_service.dart'
    as _i170;
import 'package:plantcare_ai/features/reminders/data/services/shared_preferences_notification_id_store.dart'
    as _i985;
import 'package:plantcare_ai/features/reminders/domain/repositories/reminder_repository.dart'
    as _i142;
import 'package:plantcare_ai/features/reminders/domain/services/notification_scheduler.dart'
    as _i456;
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminder_bloc_factory.dart'
    as _i208;
import 'package:plantcare_ai/features/soil_check/data/repositories/firebase_soil_check_repository.dart'
    as _i949;
import 'package:plantcare_ai/features/soil_check/domain/repositories/soil_check_repository.dart'
    as _i441;
import 'package:plantcare_ai/features/soil_check/presentation/bloc/soil_check_bloc_factory.dart'
    as _i727;

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
    gh.lazySingleton<_i852.EnvironmentConfig>(
      () => appModule.environmentConfig,
    );
    gh.lazySingleton<_i805.PlantImagePicker>(
      () => _i533.ImagePickerPlantImagePicker(),
    );
    gh.lazySingleton<_i456.NotificationIdStore>(
      () => _i985.SharedPreferencesNotificationIdStore(),
    );
    gh.lazySingleton<_i807.PlantImageProcessor>(
      () => const _i491.LocalPlantImageProcessor(),
    );
    gh.lazySingleton<_i441.SoilCheckRepository>(
      () => _i949.FirebaseSoilCheckRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i342.FirebaseAppCheckActivator>(
      () => appModule.firebaseAppCheckActivator(gh<_i852.EnvironmentConfig>()),
    );
    gh.lazySingleton<_i972.CareLogRepository>(
      () => _i729.FirebaseCareLogRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i142.ReminderRepository>(
      () => _i420.FirebaseReminderRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i154.AuthenticationRepository>(
      () => _i406.FirebaseAuthenticationRepository(gh<_i59.FirebaseAuth>()),
    );
    gh.lazySingleton<_i879.PlantRepository>(
      () => _i78.FirebasePlantRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i376.PlantDiagnosisService>(
      () => _i796.FirebaseAiPlantDiagnosisService(
        gh<_i59.FirebaseAuth>(),
        gh<_i852.EnvironmentConfig>(),
      ),
    );
    gh.lazySingleton<_i139.CareLogBlocFactory>(
      () => _i139.CareLogBlocFactory(gh<_i972.CareLogRepository>()),
    );
    gh.lazySingleton<_i2.AuthSessionBloc>(
      () => _i2.AuthSessionBloc(gh<_i154.AuthenticationRepository>()),
    );
    gh.lazySingleton<_i1017.AuthenticationBlocFactory>(
      () => _i1017.AuthenticationBlocFactory(
        gh<_i154.AuthenticationRepository>(),
      ),
    );
    gh.lazySingleton<_i687.PlantDiagnosisRepository>(
      () => _i976.FirebasePlantDiagnosisRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i963.PlantBlocFactory>(
      () => _i963.PlantBlocFactory(gh<_i879.PlantRepository>()),
    );
    gh.lazySingleton<_i819.KnowledgeRepository>(
      () => _i1064.FirebaseKnowledgeRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i304.FertilizerAssessmentRepository>(
      () => _i863.FirebaseFertilizerAssessmentRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i210.PlantObservationRepository>(
      () => _i177.FirebasePlantObservationRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i519.PlantObservationService>(
      () => _i359.FirebaseAiPlantObservationService(
        gh<_i59.FirebaseAuth>(),
        gh<_i852.EnvironmentConfig>(),
      ),
    );
    gh.lazySingleton<_i641.PlantObservationBlocFactory>(
      () => _i641.PlantObservationBlocFactory(
        gh<_i805.PlantImagePicker>(),
        gh<_i807.PlantImageProcessor>(),
        gh<_i519.PlantObservationService>(),
        gh<_i210.PlantObservationRepository>(),
      ),
    );
    gh.lazySingleton<_i456.NotificationScheduler>(
      () => _i176.LocalNotificationScheduler(gh<_i456.NotificationIdStore>()),
    );
    gh.lazySingleton<_i1029.KnowledgeRetrievalBlocFactory>(
      () =>
          _i1029.KnowledgeRetrievalBlocFactory(gh<_i819.KnowledgeRepository>()),
    );
    gh.lazySingleton<_i964.AppInitializer>(
      () => appModule.appInitializer(
        gh<_i852.EnvironmentConfig>(),
        gh<_i342.FirebaseAppCheckActivator>(),
      ),
    );
    gh.lazySingleton<_i970.FertilizerAssessmentBlocFactory>(
      () => _i970.FertilizerAssessmentBlocFactory(
        gh<_i879.PlantRepository>(),
        gh<_i972.CareLogRepository>(),
        gh<_i304.FertilizerAssessmentRepository>(),
        gh<_i819.KnowledgeRepository>(),
      ),
    );
    gh.lazySingleton<_i170.ReminderLifecycleService>(
      () => _i170.ReminderLifecycleService(
        gh<_i59.FirebaseAuth>(),
        gh<_i142.ReminderRepository>(),
        gh<_i879.PlantRepository>(),
        gh<_i456.NotificationScheduler>(),
      ),
    );
    gh.lazySingleton<_i1.PlantDiagnosisBlocFactory>(
      () => _i1.PlantDiagnosisBlocFactory(
        gh<_i819.KnowledgeRepository>(),
        gh<_i687.PlantDiagnosisRepository>(),
        gh<_i376.PlantDiagnosisService>(),
      ),
    );
    gh.lazySingleton<_i208.ReminderBlocFactory>(
      () => _i208.ReminderBlocFactory(
        gh<_i142.ReminderRepository>(),
        gh<_i456.NotificationScheduler>(),
        gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i727.SoilCheckBlocFactory>(
      () => _i727.SoilCheckBlocFactory(
        gh<_i879.PlantRepository>(),
        gh<_i441.SoilCheckRepository>(),
        gh<_i819.KnowledgeRepository>(),
      ),
    );
    gh.lazySingleton<_i583.GoRouter>(
      () => appModule.router(
        gh<_i2.AuthSessionBloc>(),
        gh<_i1017.AuthenticationBlocFactory>(),
        gh<_i963.PlantBlocFactory>(),
        gh<_i641.PlantObservationBlocFactory>(),
        gh<_i1029.KnowledgeRetrievalBlocFactory>(),
        gh<_i1.PlantDiagnosisBlocFactory>(),
        gh<_i727.SoilCheckBlocFactory>(),
        gh<_i139.CareLogBlocFactory>(),
        gh<_i970.FertilizerAssessmentBlocFactory>(),
        gh<_i208.ReminderBlocFactory>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i1018.AppModule {}
