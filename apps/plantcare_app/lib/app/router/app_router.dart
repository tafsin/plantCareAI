import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_app/core/widgets/app_shell.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/care_history.dart';
import 'package:plantcare_features/fertilizer_assessment.dart';
import 'package:plantcare_features/home.dart';
import 'package:plantcare_features/information.dart';
import 'package:plantcare_features/knowledge_retrieval.dart';
import 'package:plantcare_features/navigation.dart';
import 'package:plantcare_features/plant_diagnosis.dart';
import 'package:plantcare_features/plant_observation.dart';
import 'package:plantcare_features/plants.dart';
import 'package:plantcare_features/reminders.dart';
import 'package:plantcare_features/soil_check.dart';

String? validatedProtectedDestination(String? candidate) {
  if (candidate == null) {
    return null;
  }
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    return null;
  }
  if (!_isProtectedPath(uri.path) || uri.hasFragment) return null;
  if (!uri.hasQuery) return uri.path;
  final segments = uri.pathSegments;
  final isCareForm =
      segments.length == 4 &&
      segments.first == 'plants' &&
      segments[2] == 'care' &&
      segments[3] == 'new';
  final type = uri.queryParameters['type'];
  if (isCareForm &&
      uri.queryParameters.length == 1 &&
      const {'watering', 'fertilizing'}.contains(type)) {
    return uri.toString();
  }
  final isReminderForm =
      segments.length == 4 &&
      segments.first == 'plants' &&
      segments[2] == 'reminders' &&
      segments[3] == 'new';
  if (!isReminderForm ||
      uri.queryParameters.keys.any(
        (key) => !const {'source', 'referenceId', 'suggestedAt'}.contains(key),
      )) {
    return null;
  }
  final source = uri.queryParameters['source'];
  final reference = uri.queryParameters['referenceId'];
  final suggested = DateTime.tryParse(uri.queryParameters['suggestedAt'] ?? '');
  final validSuggestion =
      const {
        'soil_check_suggestion',
        'fertilizer_assessment_suggestion',
      }.contains(source) &&
      reference != null &&
      reference.isNotEmpty &&
      suggested != null;
  return uri.queryParameters.isEmpty || validSuggestion ? uri.toString() : null;
}

bool _isProtectedPath(String path) {
  if (path == AppRoutes.home ||
      path == AppRoutes.plants ||
      path == AppRoutes.newPlant) {
    return true;
  }
  if (path == AppRoutes.reminders || path == AppRoutes.privacySafety) {
    return true;
  }
  final segments = Uri(path: path).pathSegments;
  return segments.length == 2 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty ||
      segments.length == 3 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty &&
          const {
            'edit',
            'observe',
            'observations',
            'soil-checks',
            'fertilizer-assessments',
            'care',
            'reminders',
          }.contains(segments[2]) ||
      segments.length == 4 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty &&
          segments[2] == 'observations' &&
          segments[3].isNotEmpty ||
      segments.length == 4 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty &&
          const {
            'soil-checks',
            'care',
            'fertilizer-assessments',
            'reminders',
          }.contains(segments[2]) &&
          segments[3].isNotEmpty ||
      segments.length == 5 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty &&
          segments[2] == 'observations' &&
          segments[3].isNotEmpty &&
          const {'diagnose', 'diagnoses'}.contains(segments[4]) ||
      segments.length == 6 &&
          segments.first == 'plants' &&
          segments[1].isNotEmpty &&
          segments[2] == 'observations' &&
          segments[3].isNotEmpty &&
          segments[4] == 'diagnoses' &&
          segments[5].isNotEmpty;
}

GoRouter createAppRouter({
  required AuthSessionBloc authSessionBloc,
  required AuthenticationBlocFactory authenticationBlocFactory,
  required PlantBlocFactory plantBlocFactory,
  PlantObservationBlocFactory? plantObservationBlocFactory,
  KnowledgeRetrievalBlocFactory? knowledgeRetrievalBlocFactory,
  PlantDiagnosisBlocFactory? plantDiagnosisBlocFactory,
  SoilCheckBlocFactory? soilCheckBlocFactory,
  CareLogBlocFactory? careLogBlocFactory,
  FertilizerAssessmentBlocFactory? fertilizerAssessmentBlocFactory,
  ReminderBlocFactory? reminderBlocFactory,
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
        final requestedDestination = validatedProtectedDestination(
          state.uri.toString(),
        );
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
            pageBuilder: (context, state) => NoTransitionPage(
              child: reminderBlocFactory == null
                  ? const HomePage()
                  : BlocProvider<RemindersBloc>(
                      create: (_) =>
                          reminderBlocFactory.createListBloc()
                            ..add(const RemindersWatchRequested()),
                      child: const HomePage(),
                    ),
            ),
          ),
          GoRoute(
            path: AppRoutes.privacySafety,
            builder: (context, state) => const PrivacySafetyPage(),
          ),
          if (reminderBlocFactory != null)
            GoRoute(
              path: AppRoutes.reminders,
              pageBuilder: (context, state) => NoTransitionPage(
                child: BlocProvider<RemindersBloc>(
                  create: (_) =>
                      reminderBlocFactory.createListBloc()
                        ..add(const RemindersWatchRequested()),
                  child: const RemindersPage(),
                ),
              ),
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
              return MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) =>
                        plantBlocFactory.createPlantDetailsBloc()
                          ..add(PlantDetailsWatchRequested(plantId)),
                  ),
                  if (soilCheckBlocFactory != null)
                    BlocProvider<SoilCheckHistoryBloc>(
                      create: (_) =>
                          soilCheckBlocFactory.createHistoryBloc()
                            ..add(SoilCheckHistoryWatchRequested(plantId)),
                    ),
                  if (careLogBlocFactory != null)
                    BlocProvider<CareHistoryBloc>(
                      create: (_) =>
                          careLogBlocFactory.createHistoryBloc()
                            ..add(CareHistoryWatchRequested(plantId)),
                    ),
                  if (fertilizerAssessmentBlocFactory != null)
                    BlocProvider<FertilizerAssessmentHistoryBloc>(
                      create: (_) =>
                          fertilizerAssessmentBlocFactory.createHistoryBloc()
                            ..add(
                              FertilizerAssessmentHistoryWatchRequested(
                                plantId,
                              ),
                            ),
                    ),
                  if (reminderBlocFactory != null)
                    BlocProvider<RemindersBloc>(
                      create: (_) =>
                          reminderBlocFactory.createListBloc()
                            ..add(RemindersWatchRequested(plantId)),
                    ),
                ],
                child: PlantDetailsPage(
                  plantId: plantId,
                  enableSoilChecks: soilCheckBlocFactory != null,
                  enableCareLogs: careLogBlocFactory != null,
                  enableFertilizerAssessments:
                      fertilizerAssessmentBlocFactory != null,
                  enableReminders: reminderBlocFactory != null,
                ),
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
            if (plantDiagnosisBlocFactory != null) ...[
              GoRoute(
                path: '/plants/:plantId/observations/:observationId/diagnose',
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
                            plantObservationBlocFactory.createDetailsBloc()
                              ..add(
                                ObservationDetailsWatchRequested(
                                  plantId,
                                  observationId,
                                ),
                              ),
                      ),
                      BlocProvider<PlantDiagnosisBloc>(
                        create: (_) =>
                            plantDiagnosisBlocFactory.createDiagnosisBloc(),
                      ),
                    ],
                    child: PlantDiagnosisPage(
                      plantId: plantId,
                      observationId: observationId,
                    ),
                  );
                },
              ),
              GoRoute(
                path: '/plants/:plantId/observations/:observationId/diagnoses',
                builder: (context, state) {
                  final plantId = state.pathParameters['plantId'] ?? '';
                  final observationId =
                      state.pathParameters['observationId'] ?? '';
                  return BlocProvider<DiagnosisHistoryBloc>(
                    create: (_) => plantDiagnosisBlocFactory.createHistoryBloc()
                      ..add(
                        DiagnosisHistoryWatchRequested(plantId, observationId),
                      ),
                    child: DiagnosisHistoryPage(
                      plantId: plantId,
                      observationId: observationId,
                    ),
                  );
                },
              ),
              GoRoute(
                path: '/plants/:plantId/observations/:observationId/diagnoses/:diagnosisId',
                builder: (context, state) {
                  final plantId = state.pathParameters['plantId'] ?? '';
                  final observationId =
                      state.pathParameters['observationId'] ?? '';
                  final diagnosisId = state.pathParameters['diagnosisId'] ?? '';
                  return BlocProvider<DiagnosisDetailsBloc>(
                    create: (_) => plantDiagnosisBlocFactory.createDetailsBloc()
                      ..add(
                        DiagnosisDetailsWatchRequested(
                          plantId,
                          observationId,
                          diagnosisId,
                        ),
                      ),
                    child: DiagnosisDetailsPage(
                      plantId: plantId,
                      observationId: observationId,
                    ),
                  );
                },
              ),
            ],
          ],
          if (soilCheckBlocFactory != null) ...[
            GoRoute(
              path: '/plants/:plantId/soil-checks/new',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                return BlocProvider<SoilCheckBloc>(
                  create: (_) =>
                      soilCheckBlocFactory.createCheckBloc()
                        ..add(SoilCheckStarted(plantId)),
                  child: NewSoilCheckPage(plantId: plantId),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/soil-checks',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                return BlocProvider<SoilCheckHistoryBloc>(
                  create: (_) =>
                      soilCheckBlocFactory.createHistoryBloc()
                        ..add(SoilCheckHistoryWatchRequested(plantId)),
                  child: SoilCheckHistoryPage(plantId: plantId),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/soil-checks/:soilCheckId',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                final soilCheckId = state.pathParameters['soilCheckId'] ?? '';
                return BlocProvider<SoilCheckDetailsBloc>(
                  create: (_) => soilCheckBlocFactory.createDetailsBloc()
                    ..add(SoilCheckDetailsWatchRequested(plantId, soilCheckId)),
                  child: SoilCheckDetailsPage(
                    plantId: plantId,
                    soilCheckId: soilCheckId,
                  ),
                );
              },
            ),
          ],
          if (fertilizerAssessmentBlocFactory != null) ...[
            GoRoute(
              path: '/plants/:plantId/fertilizer-assessments/new',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                return BlocProvider<FertilizerAssessmentBloc>(
                  create: (_) =>
                      fertilizerAssessmentBlocFactory.createAssessmentBloc()
                        ..add(FertilizerAssessmentStarted(plantId)),
                  child: NewFertilizerAssessmentPage(plantId: plantId),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/fertilizer-assessments',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                return BlocProvider<FertilizerAssessmentHistoryBloc>(
                  create: (_) =>
                      fertilizerAssessmentBlocFactory.createHistoryBloc()..add(
                        FertilizerAssessmentHistoryWatchRequested(plantId),
                      ),
                  child: FertilizerAssessmentHistoryPage(plantId: plantId),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/fertilizer-assessments/:assessmentId',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                final assessmentId = state.pathParameters['assessmentId'] ?? '';
                return BlocProvider<FertilizerAssessmentDetailsBloc>(
                  create: (_) =>
                      fertilizerAssessmentBlocFactory.createDetailsBloc()..add(
                        FertilizerAssessmentDetailsWatchRequested(
                          plantId,
                          assessmentId,
                        ),
                      ),
                  child: FertilizerAssessmentDetailsPage(
                    plantId: plantId,
                    assessmentId: assessmentId,
                  ),
                );
              },
            ),
          ],
          if (careLogBlocFactory != null) ...[
            GoRoute(
              path: '/plants/:plantId/care',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) =>
                          plantBlocFactory.createPlantDetailsBloc()
                            ..add(PlantDetailsWatchRequested(plantId)),
                    ),
                    BlocProvider<CareHistoryBloc>(
                      create: (_) =>
                          careLogBlocFactory.createHistoryBloc()
                            ..add(CareHistoryWatchRequested(plantId)),
                    ),
                  ],
                  child: CarePlantGuard(
                    plantId: plantId,
                    child: CareHistoryPage(plantId: plantId),
                  ),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/care/new',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                final type = switch (state.uri.queryParameters['type']) {
                  'watering' => CareLogType.watering,
                  'fertilizing' => CareLogType.fertilizing,
                  _ => null,
                };
                if (type == null) {
                  return InvalidCareLogTypePage(plantId: plantId);
                }
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) =>
                          plantBlocFactory.createPlantDetailsBloc()
                            ..add(PlantDetailsWatchRequested(plantId)),
                    ),
                    BlocProvider(
                      create: (_) =>
                          careLogBlocFactory.createFormBloc(plantId, type),
                    ),
                  ],
                  child: CarePlantGuard(
                    plantId: plantId,
                    child: CareLogFormPage(plantId: plantId, type: type),
                  ),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/care/:careLogId',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                final careLogId = state.pathParameters['careLogId'] ?? '';
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) =>
                          plantBlocFactory.createPlantDetailsBloc()
                            ..add(PlantDetailsWatchRequested(plantId)),
                    ),
                    BlocProvider<CareLogDetailsBloc>(
                      create: (_) => careLogBlocFactory.createDetailsBloc(
                        plantId,
                        careLogId,
                      )..add(const CareLogDetailsRequested()),
                    ),
                  ],
                  child: CarePlantGuard(
                    plantId: plantId,
                    child: CareLogDetailsPage(plantId: plantId),
                  ),
                );
              },
            ),
          ],
          if (reminderBlocFactory != null) ...[
            GoRoute(
              path: '/plants/:plantId/reminders/new',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                final source = switch (state.uri.queryParameters['source']) {
                  'soil_check_suggestion' => ReminderSource.soilCheckSuggestion,
                  'fertilizer_assessment_suggestion' =>
                    ReminderSource.fertilizerAssessmentSuggestion,
                  _ => ReminderSource.userCreated,
                };
                final referenceId = state.uri.queryParameters['referenceId'];
                final suggestedAt = DateTime.tryParse(
                  state.uri.queryParameters['suggestedAt'] ?? '',
                );
                return BlocProvider(
                  create: (_) => reminderBlocFactory.createFormBloc(
                    plantId: plantId,
                    plantName: state.extra is String
                        ? state.extra! as String
                        : 'your plant',
                    source: source,
                    suggestedAt: suggestedAt,
                    soilCheckId: source == ReminderSource.soilCheckSuggestion
                        ? referenceId
                        : null,
                    fertilizerAssessmentId:
                        source == ReminderSource.fertilizerAssessmentSuggestion
                        ? referenceId
                        : null,
                  ),
                  child: ReminderFormPage(plantId: plantId),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/reminders',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                return BlocProvider<RemindersBloc>(
                  create: (_) =>
                      reminderBlocFactory.createListBloc()
                        ..add(RemindersWatchRequested(plantId)),
                  child: RemindersPage(plantId: plantId),
                );
              },
            ),
            GoRoute(
              path: '/plants/:plantId/reminders/:reminderId',
              builder: (context, state) {
                final plantId = state.pathParameters['plantId'] ?? '';
                final reminderId = state.pathParameters['reminderId'] ?? '';
                return BlocProvider<ReminderDetailsBloc>(
                  create: (_) =>
                      reminderBlocFactory.createDetailsBloc(plantId, reminderId)
                        ..add(const ReminderDetailsWatchRequested()),
                  child: ReminderDetailsPage(plantId: plantId),
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
