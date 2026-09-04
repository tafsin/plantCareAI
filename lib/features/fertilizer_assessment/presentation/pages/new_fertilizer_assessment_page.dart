import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/care_history/presentation/widgets/care_log_labels.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_bloc.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/widgets/fertilizer_assessment_labels.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/widgets/fertilizer_guidance_view.dart';
import 'package:plantcare_ai/features/navigation/presentation/app_routes.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';

class NewFertilizerAssessmentPage extends StatelessWidget {
  const NewFertilizerAssessmentPage({required this.plantId, super.key});
  final String plantId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fertilizer guidance')),
    body: BlocBuilder<FertilizerAssessmentBloc, FertilizerAssessmentState>(
      builder: (context, state) {
        if (state.status == FertilizerAssessmentStatus.initial ||
            state.status == FertilizerAssessmentStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.plant == null) {
          return _Message(
            message: state.errorMessage ?? 'Plant not found.',
            onRetry: () => context.read<FertilizerAssessmentBloc>().add(
              FertilizerAssessmentStarted(plantId),
            ),
          );
        }
        final busy =
            state.status == FertilizerAssessmentStatus.calculating ||
            state.status == FertilizerAssessmentStatus.saving;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Current evidence',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Plant: ${state.plant!.commonName}'),
                  Text('Growth stage: ${state.plant!.growthStage.name}'),
                  Text(
                    state.lastFertilizingLog == null
                        ? 'No fertilizer history is recorded. That alone does not mean fertilizer is needed.'
                        : 'Last fertilized: ${careDateLabel(state.lastFertilizingLog!.occurredAt)}',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'What is the plant doing now?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...GrowthActivity.values.map(
                    (activity) => Card(
                      color: state.growthActivity == activity
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      child: ListTile(
                        key: ValueKey('growth-${activity.value}'),
                        enabled: !busy,
                        selected: state.growthActivity == activity,
                        leading: Icon(
                          state.growthActivity == activity
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(activity.label),
                        subtitle: Text(activity.description),
                        onTap: busy
                            ? null
                            : () =>
                                  context.read<FertilizerAssessmentBloc>().add(
                                    FertilizerGrowthActivitySelected(activity),
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('calculate-fertilizer-assessment'),
                    onPressed: busy || state.growthActivity == null
                        ? null
                        : () => context.read<FertilizerAssessmentBloc>().add(
                            FertilizerAssessmentSubmitted(
                              assessmentTime: DateTime.now(),
                            ),
                          ),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.eco_outlined),
                    label: Text(
                      busy ? 'Assessing…' : 'Get fertilizer guidance',
                    ),
                  ),
                  if (state.guidance != null) ...[
                    const SizedBox(height: 20),
                    FertilizerGuidanceView(
                      guidance: state.guidance!,
                      sources: state.sources,
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (state.saveRetryAvailable) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context
                          .read<FertilizerAssessmentBloc>()
                          .add(const FertilizerAssessmentSaveRetried()),
                      child: const Text('Retry save without recalculating'),
                    ),
                  ],
                  if (state.status == FertilizerAssessmentStatus.saved) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => context.go(
                        AppRoutes.fertilizerAssessmentHistory(plantId),
                      ),
                      child: const Text('View assessment history'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
