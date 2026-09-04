import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/core/widgets/app_shell.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/auth_session_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/authentication_bloc_factory.dart';
import 'package:plantcare_ai/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:plantcare_ai/features/authentication/presentation/pages/register_page.dart';
import 'package:plantcare_ai/features/authentication/presentation/pages/sign_in_page.dart';
import 'package:plantcare_ai/features/home/presentation/pages/home_page.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc_factory.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/observation_details_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/observation_history_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/plant_observation_bloc_factory.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/pages/observation_details_page.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/pages/observation_history_page.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/pages/plant_observation_page.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_bloc_factory.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plants_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/pages/my_plants_page.dart';
import 'package:plantcare_ai/features/plants/presentation/pages/plant_details_page.dart';
import 'package:plantcare_ai/features/plants/presentation/pages/plant_form_page.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const plants = '/plants';
  static const newPlant = '/plants/new';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static const authenticationLocations = {signIn, register, forgotPassword};

  static String plantDetails(String plantId) =>
      '/plants/${Uri.encodeComponent(plantId)}';

  static String editPlant(String plantId) => '${plantDetails(plantId)}/edit';

  static String observePlant(String plantId) =>
      '${plantDetails(plantId)}/observe';

  static String observationHistory(String plantId) =>
      '${plantDetails(plantId)}/observations';

  static String observationDetails(String plantId, String observationId) =>
      '${observationHistory(plantId)}/${Uri.encodeComponent(observationId)}';

  static String signInLocation(String? redirect) =>
      _authLocation(signIn, redirect);

  static String registerLocation(String? redirect) =>
      _authLocation(register, redirect);

  static String forgotPasswordLocation(String? redirect) =>
      _authLocation(forgotPassword, redirect);

  static String _authLocation(String path, String? redirect) {
    final destination = validatedProtectedDestination(redirect);
    return Uri(
      path: path,
      queryParameters: destination == null ? null : {'redirect': destination},
    ).toString();
  }
}

String? validatedProtectedDestination(String? candidate) {
  if (candidate == null) {
    return null;
  }
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    return null;
  }
  return _isProtectedPath(uri.path) && !uri.hasQuery && !uri.hasFragment
      ? uri.path
      : null;
}

bool _isProtectedPath(String path) {
  if (path == AppRoutes.home ||
      path == AppRoutes.plants ||
      path == AppRoutes.newPlant) {
    return true;
  }
  final segments = Uri(path: path).pathSegments;
  return segments.length == 2 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty ||
      segments.length == 3 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty &&
          const {'edit', 'observe', 'observations'}.contains(segments[2]) ||
      segments.length == 4 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty &&
          segments[2] == 'observations' &&
          segments[3].isNotEmpty;
}

GoRouter createAppRouter({
  required AuthSessionBloc authSessionBloc,
  required AuthenticationBlocFactory authenticationBlocFactory,
  required PlantBlocFactory plantBlocFactory,
  PlantObservationBlocFactory? plantObservationBlocFactory,
  KnowledgeRetrievalBlocFactory? knowledgeRetrievalBlocFactory,
  String initialLocation = AppRoutes.home,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authSessionBloc,
    redirect: (context, state) {
      final sessionState = authSessionBloc.state;
      if (sessionState is AuthSessionChecking) {
        return null;
      }

      final path = state.uri.path;
      final isAuthenticationRoute = AppRoutes.authenticationLocations.contains(
        path,
      );
      final redirect = validatedProtectedDestination(
        state.uri.queryParameters['redirect'],
      );

      if (sessionState is AuthSessionUnauthenticated) {
        if (isAuthenticationRoute) {
          return null;
        }
        final requestedDestination = validatedProtectedDestination(path);
        return AppRoutes.signInLocation(requestedDestination);
      }

      if (sessionState is AuthSessionAuthenticated && isAuthenticationRoute) {
        return redirect ?? AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => BlocProvider(
          create: (_) => authenticationBlocFactory.createSignInBloc(),
          child: SignInPage(
            redirect: validatedProtectedDestination(
              state.uri.queryParameters['redirect'],
            ),
            notice: state.extra is String ? state.extra! as String : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => BlocProvider(
          create: (_) => authenticationBlocFactory.createRegisterBloc(),
          child: RegisterPage(
            redirect: validatedProtectedDestination(
              state.uri.queryParameters['redirect'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => BlocProvider(
          create: (_) => authenticationBlocFactory.createPasswordResetBloc(),
          child: ForgotPasswordPage(
            redirect: validatedProtectedDestination(
              state.uri.queryParameters['redirect'],
            ),
          ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (_) =>
                plantBlocFactory.createPlantsBloc()
                  ..add(const PlantsWatchRequested()),
            child: AppShell(location: state.uri.path, child: child),
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: AppRoutes.plants,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MyPlantsPage()),
          ),
          GoRoute(
            path: AppRoutes.newPlant,
            builder: (context, state) => BlocProvider(
              create: (_) => plantBlocFactory.createPlantFormBloc(),
              child: const PlantFormPage(),
            ),
          ),
          GoRoute(
            path: '/plants/:plantId',
            builder: (context, state) {
              final plantId = state.pathParameters['plantId'] ?? '';
              return BlocProvider(
                create: (_) =>
                    plantBlocFactory.createPlantDetailsBloc()
                      ..add(PlantDetailsWatchRequested(plantId)),
                child: PlantDetailsPage(plantId: plantId),
              );
            },
          ),
          GoRoute(
            path: '/plants/:plantId/edit',
            builder: (context, state) {
              final plantId = state.pathParameters['plantId'] ?? '';
              return MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) =>
                        plantBlocFactory.createPlantDetailsBloc()
                          ..add(PlantDetailsWatchRequested(plantId)),
                  ),
                  BlocProvider(
                    create: (_) => plantBlocFactory.createPlantFormBloc(),
                  ),
                ],
                child: const EditPlantPage(),
              );
            },
          ),
          if (plantObservationBlocFactory != null) ...[
            GoRoute(
              path: '/plants/:plantId/observe',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) =>
                          plantBlocFactory.createPlantDetailsBloc()
                            ..add(PlantDetailsWatchRequested(plantId)),
                    ),
                    BlocProvider(
                      create: (_) =>
                          plantObservationBlocFactory.createObservationBloc(),
                    ),
                  ],
                  child: PlantObservationPage(plantId: plantId),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/observations',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) =>
                          plantBlocFactory.createPlantDetailsBloc()
                            ..add(PlantDetailsWatchRequested(plantId)),
                    ),
                    BlocProvider<ObservationHistoryBloc>(
                      create: (_) =>
                          plantObservationBlocFactory.createHistoryBloc()
                            ..add(ObservationHistoryWatchRequested(plantId)),
                    ),
                  ],
                  child: ObservationHistoryPage(plantId: plantId),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/observations/:observationId',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                final observationId =
                    state.pathParameters['observationId'] ?? '';
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) =>
                          plantBlocFactory.createPlantDetailsBloc()
                            ..add(PlantDetailsWatchRequested(plantId)),
                    ),
                    BlocProvider<ObservationDetailsBloc>(
                      create: (_) =>
                          plantObservationBlocFactory.createDetailsBloc()..add(
                            ObservationDetailsWatchRequested(
                              plantId,
                              observationId,
                            ),
                          ),
                    ),
                    if (knowledgeRetrievalBlocFactory != null)
                      BlocProvider<KnowledgeRetrievalBloc>(
                        create: (_) => knowledgeRetrievalBlocFactory.create(),
                      ),
                  ],
                  child: ObservationDetailsPage(
                    plantId: plantId,
                    observationId: observationId,
                    enableKnowledgeRetrieval:
                        knowledgeRetrievalBlocFactory != null,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
  );
}
