import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_details_bloc.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/widgets/fertilizer_assessment_labels.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/widgets/fertilizer_guidance_view.dart';
import 'package:plantcare_ai/features/navigation/presentation/app_routes.dart';
import 'package:plantcare_domain/reminders.dart';

class FertilizerAssessmentDetailsPage extends StatelessWidget {
  const FertilizerAssessmentDetailsPage({
    required this.plantId,
    required this.assessmentId,
    super.key,
  });
  final String plantId;
  final String assessmentId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fertilizer assessment details')),
    body:
        BlocBuilder<
          FertilizerAssessmentDetailsBloc,
          FertilizerAssessmentDetailsState
        >(
          builder: (context, state) => switch (state.status) {
            FertilizerAssessmentDetailsStatus.initial ||
            FertilizerAssessmentDetailsStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            FertilizerAssessmentDetailsStatus.notFound => const Center(
              child: Text('Fertilizer assessment not found.'),
            ),
            FertilizerAssessmentDetailsStatus.failure => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Couldn’t load this assessment.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        context.read<FertilizerAssessmentDetailsBloc>().add(
                          FertilizerAssessmentDetailsWatchRequested(
                            plantId,
                            assessmentId,
                          ),
                        ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            FertilizerAssessmentDetailsStatus.loaded => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        state.item!.createdAt?.toLocal().toString() ??
                            'Timestamp pending',
                      ),
                      const SizedBox(height: 16),
                      FertilizerGuidanceView(
                        guidance: state.item!.guidance,
                        sources: state.sources,
                      ),
                      if (state.item!.guidance.suggestedReviewAt
                          case final dueAt?) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => context.go(
                            AppRoutes.newReminder(
                              plantId,
                              source:
                                  ReminderSource.fertilizerAssessmentSuggestion,
                              referenceId: assessmentId,
                              suggestedAt: dueAt,
                            ),
                          ),
                          icon: const Icon(Icons.add_alert),
                          label: const Text('Review suggested reminder'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Growth activity: ${state.item!.growthActivity.label}',
                      ),
                      Text(
                        'Growth-stage snapshot: ${state.item!.growthStageSnapshot.name}',
                      ),
                      Text(
                        'Environment snapshot: ${state.item!.environmentSnapshot.name}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          },
        ),
  );
}
