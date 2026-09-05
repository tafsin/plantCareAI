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
import 'package:plantcare_app/app/application/reminder_lifecycle_service.dart'
    as _i745;
import 'package:plantcare_app/app/bootstrap/app_initializer.dart' as _i484;
import 'package:plantcare_app/app/bootstrap/firebase_app_check_activator.dart'
    as _i767;
import 'package:plantcare_app/app/dependency_injection/app_module.dart'
    as _i203;
import 'package:plantcare_app/app/theme/theme_bloc.dart' as _i393;
import 'package:plantcare_data/data_module.dart' as _i74;
import 'package:plantcare_domain/authentication.dart' as _i521;
import 'package:plantcare_domain/plants.dart' as _i867;
import 'package:plantcare_domain/reminders.dart' as _i412;
import 'package:plantcare_features/authentication.dart' as _i712;
import 'package:plantcare_features/care_history.dart' as _i323;
import 'package:plantcare_features/features_module.dart' as _i30;
import 'package:plantcare_features/fertilizer_assessment.dart' as _i60;
import 'package:plantcare_features/knowledge_retrieval.dart' as _i499;
import 'package:plantcare_features/plant_diagnosis.dart' as _i407;
import 'package:plantcare_features/plant_identification.dart' as _i698;
import 'package:plantcare_features/plant_observation.dart' as _i840;
import 'package:plantcare_features/plants.dart' as _i311;
import 'package:plantcare_features/reminders.dart' as _i847;
import 'package:plantcare_features/soil_check.dart' as _i852;
import 'package:plantcare_shared/environment.dart' as _i515;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    await _i74.PlantcareDataPackageModule().init(gh);
    await _i30.PlantcareFeaturesPackageModule().init(gh);
    final appModule = _$AppModule();
    gh.factory<_i393.ThemeBloc>(() => _i393.ThemeBloc());
    gh.lazySingleton<_i59.FirebaseAuth>(() => appModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(
      () => appModule.firebaseFirestore,
    );
    gh.lazySingleton<_i515.EnvironmentConfig>(
      () => appModule.environmentConfig,
    );
    gh.lazySingleton<_i583.GoRouter>(
      () => appModule.router(
        gh<_i712.AuthSessionBloc>(),
        gh<_i712.AuthenticationBlocFactory>(),
        gh<_i311.PlantBlocFactory>(),
        gh<_i698.PlantIdentificationBlocFactory>(),
        gh<_i840.PlantObservationBlocFactory>(),
        gh<_i499.KnowledgeRetrievalBlocFactory>(),
        gh<_i407.PlantDiagnosisBlocFactory>(),
        gh<_i852.SoilCheckBlocFactory>(),
        gh<_i323.CareLogBlocFactory>(),
        gh<_i60.FertilizerAssessmentBlocFactory>(),
        gh<_i847.ReminderBlocFactory>(),
      ),
    );
    gh.lazySingleton<_i767.FirebaseAppCheckActivator>(
      () => appModule.firebaseAppCheckActivator(gh<_i515.EnvironmentConfig>()),
    );
    gh.lazySingleton<_i521.AuthenticationSession>(
      () =>
          appModule.authenticationSession(gh<_i521.AuthenticationRepository>()),
    );
    gh.lazySingleton<_i484.AppInitializer>(
      () => appModule.appInitializer(
        gh<_i515.EnvironmentConfig>(),
        gh<_i767.FirebaseAppCheckActivator>(),
      ),
    );
    gh.lazySingleton<_i745.ReminderLifecycleService>(
      () => _i745.ReminderLifecycleService(
        gh<_i521.AuthenticationSession>(),
        gh<_i412.ReminderRepository>(),
        gh<_i867.PlantRepository>(),
        gh<_i412.NotificationScheduler>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i203.AppModule {}
