import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_app/app/application/reminder_lifecycle_service.dart';
import 'package:plantcare_app/app/bootstrap/app_initializer.dart';
import 'package:plantcare_app/app/bootstrap/firebase_app_check_activator.dart';
import 'package:plantcare_app/app/bootstrap/firebase_app_initializer.dart';
import 'package:plantcare_app/app/bootstrap/firebase_auth_emulator.dart';
import 'package:plantcare_app/app/config/compile_time_environment_config.dart';
import 'package:plantcare_app/app/router/app_router.dart';
import 'package:plantcare_app/firebase_options.dart';
import 'package:plantcare_domain/authentication.dart';
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

@module
abstract class AppModule {
  @lazySingleton
  GoRouter router(
    AuthSessionBloc authSessionBloc,
    AuthenticationBlocFactory authenticationBlocFactory,
    PlantBlocFactory plantBlocFactory,
    PlantIdentificationBlocFactory plantIdentificationBlocFactory,
    PlantObservationBlocFactory plantObservationBlocFactory,
    KnowledgeRetrievalBlocFactory knowledgeRetrievalBlocFactory,
    PlantDiagnosisBlocFactory plantDiagnosisBlocFactory,
    SoilCheckBlocFactory soilCheckBlocFactory,
    CareLogBlocFactory careLogBlocFactory,
    FertilizerAssessmentBlocFactory fertilizerAssessmentBlocFactory,
    ReminderBlocFactory reminderBlocFactory,
  ) => createAppRouter(
    authSessionBloc: authSessionBloc,
    authenticationBlocFactory: authenticationBlocFactory,
    plantBlocFactory: plantBlocFactory,
    plantIdentificationBlocFactory: plantIdentificationBlocFactory,
    plantObservationBlocFactory: plantObservationBlocFactory,
    knowledgeRetrievalBlocFactory: knowledgeRetrievalBlocFactory,
    plantDiagnosisBlocFactory: plantDiagnosisBlocFactory,
    soilCheckBlocFactory: soilCheckBlocFactory,
    careLogBlocFactory: careLogBlocFactory,
    fertilizerAssessmentBlocFactory: fertilizerAssessmentBlocFactory,
    reminderBlocFactory: reminderBlocFactory,
  );

  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @lazySingleton
  AuthenticationSession authenticationSession(
    AuthenticationRepository repository,
  ) => repository;

  @lazySingleton
  EnvironmentConfig get environmentConfig =>
      const CompileTimeEnvironmentConfig();

  @lazySingleton
  FirebaseAppCheckActivator firebaseAppCheckActivator(
    EnvironmentConfig environmentConfig,
  ) => FirebaseAppCheckActivator(environmentConfig);

  @lazySingleton
  AppInitializer appInitializer(
    EnvironmentConfig environmentConfig,
    FirebaseAppCheckActivator appCheckActivator,
  ) => FirebaseAppInitializer(
    options: DefaultFirebaseOptions.currentPlatform,
    configureEmulators: () => configureFirebaseEmulators(
      firebaseAuth: FirebaseAuth.instance,
      firebaseFirestore: FirebaseFirestore.instance,
      environmentConfig: environmentConfig,
    ),
    activateAppCheck: appCheckActivator.activate,
    // Resolve Firebase-backed services only after Firebase, emulators, and
    // App Check have completed their bootstrap stages.
    startApplicationServices: () =>
        GetIt.instance<ReminderLifecycleService>().start(),
  );
}
