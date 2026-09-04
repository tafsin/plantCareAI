import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart';
import 'package:plantcare_ai/app/bootstrap/firebase_app_check_activator.dart';
import 'package:plantcare_ai/app/bootstrap/firebase_app_initializer.dart';
import 'package:plantcare_ai/app/bootstrap/firebase_auth_emulator.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/core/utils/environment_config.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/auth_session_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/authentication_bloc_factory.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc_factory.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/plant_observation_bloc_factory.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_bloc_factory.dart';
import 'package:plantcare_ai/firebase_options.dart';

@module
abstract class AppModule {
  @lazySingleton
  GoRouter router(
    AuthSessionBloc authSessionBloc,
    AuthenticationBlocFactory authenticationBlocFactory,
    PlantBlocFactory plantBlocFactory,
    PlantObservationBlocFactory plantObservationBlocFactory,
    KnowledgeRetrievalBlocFactory knowledgeRetrievalBlocFactory,
  ) => createAppRouter(
    authSessionBloc: authSessionBloc,
    authenticationBlocFactory: authenticationBlocFactory,
    plantBlocFactory: plantBlocFactory,
    plantObservationBlocFactory: plantObservationBlocFactory,
    knowledgeRetrievalBlocFactory: knowledgeRetrievalBlocFactory,
  );

  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

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
  );
}
