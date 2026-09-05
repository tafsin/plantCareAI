// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:plantcare_domain/authentication.dart' as _i521;
import 'package:plantcare_domain/care_history.dart' as _i82;
import 'package:plantcare_domain/fertilizer_assessment.dart' as _i726;
import 'package:plantcare_domain/knowledge_retrieval.dart' as _i941;
import 'package:plantcare_domain/plant_diagnosis.dart' as _i823;
import 'package:plantcare_domain/plant_observation.dart' as _i449;
import 'package:plantcare_domain/plants.dart' as _i867;
import 'package:plantcare_domain/reminders.dart' as _i412;
import 'package:plantcare_domain/soil_check.dart' as _i658;
import 'package:plantcare_features/src/authentication/presentation/bloc/auth_session_bloc.dart'
    as _i584;
import 'package:plantcare_features/src/authentication/presentation/bloc/authentication_bloc_factory.dart'
    as _i384;
import 'package:plantcare_features/src/care_history/presentation/bloc/care_log_bloc_factory.dart'
    as _i870;
import 'package:plantcare_features/src/fertilizer_assessment/presentation/bloc/fertilizer_assessment_bloc_factory.dart'
    as _i401;
import 'package:plantcare_features/src/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc_factory.dart'
    as _i1060;
import 'package:plantcare_features/src/plant_diagnosis/presentation/bloc/plant_diagnosis_bloc_factory.dart'
    as _i287;
import 'package:plantcare_features/src/plant_observation/presentation/bloc/plant_observation_bloc_factory.dart'
    as _i30;
import 'package:plantcare_features/src/plants/presentation/bloc/plant_bloc_factory.dart'
    as _i942;
import 'package:plantcare_features/src/reminders/presentation/bloc/reminder_bloc_factory.dart'
    as _i40;
import 'package:plantcare_features/src/soil_check/presentation/bloc/soil_check_bloc_factory.dart'
    as _i497;

class PlantcareFeaturesPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i584.AuthSessionBloc>(
      () => _i584.AuthSessionBloc(gh<_i521.AuthenticationRepository>()),
    );
    gh.lazySingleton<_i384.AuthenticationBlocFactory>(
      () =>
          _i384.AuthenticationBlocFactory(gh<_i521.AuthenticationRepository>()),
    );
    gh.lazySingleton<_i401.FertilizerAssessmentBlocFactory>(
      () => _i401.FertilizerAssessmentBlocFactory(
        gh<_i867.PlantRepository>(),
        gh<_i82.CareLogRepository>(),
        gh<_i726.FertilizerAssessmentRepository>(),
        gh<_i941.KnowledgeRepository>(),
      ),
    );
    gh.lazySingleton<_i1060.KnowledgeRetrievalBlocFactory>(
      () =>
          _i1060.KnowledgeRetrievalBlocFactory(gh<_i941.KnowledgeRepository>()),
    );
    gh.lazySingleton<_i870.CareLogBlocFactory>(
      () => _i870.CareLogBlocFactory(gh<_i82.CareLogRepository>()),
    );
    gh.lazySingleton<_i287.PlantDiagnosisBlocFactory>(
      () => _i287.PlantDiagnosisBlocFactory(
        gh<_i941.KnowledgeRepository>(),
        gh<_i823.PlantDiagnosisRepository>(),
        gh<_i823.PlantDiagnosisService>(),
      ),
    );
    gh.lazySingleton<_i30.PlantObservationBlocFactory>(
      () => _i30.PlantObservationBlocFactory(
        gh<_i449.PlantImagePicker>(),
        gh<_i449.PlantImageProcessor>(),
        gh<_i449.PlantObservationService>(),
        gh<_i449.PlantObservationRepository>(),
      ),
    );
    gh.lazySingleton<_i942.PlantBlocFactory>(
      () => _i942.PlantBlocFactory(gh<_i867.PlantRepository>()),
    );
    gh.lazySingleton<_i497.SoilCheckBlocFactory>(
      () => _i497.SoilCheckBlocFactory(
        gh<_i867.PlantRepository>(),
        gh<_i658.SoilCheckRepository>(),
        gh<_i941.KnowledgeRepository>(),
      ),
    );
    gh.lazySingleton<_i40.ReminderBlocFactory>(
      () => _i40.ReminderBlocFactory(
        gh<_i412.ReminderRepository>(),
        gh<_i412.NotificationScheduler>(),
        gh<_i521.AuthenticationSession>(),
      ),
    );
  }
}
