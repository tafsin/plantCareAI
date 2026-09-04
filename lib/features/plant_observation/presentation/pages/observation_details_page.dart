import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/widgets/knowledge_retrieval_panel.dart';
import 'package:plantcare_ai/features/navigation/presentation/app_routes.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/observation_details_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/widgets/observation_result_view.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/widgets/plant_labels.dart';

class ObservationDetailsPage extends StatelessWidget {
  const ObservationDetailsPage({
    required this.plantId,
    required this.observationId,
    this.enableKnowledgeRetrieval = true,
    super.key,
  });
  final String plantId;
  final String observationId;
  final bool enableKnowledgeRetrieval;

  @override
  Widget build(BuildContext context) {
    final plantState = context.watch<PlantDetailsBloc>().state;
    if (plantState.status == PlantDetailsStatus.loading ||
        plantState.status == PlantDetailsStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (plantState.status == PlantDetailsStatus.notFound) {
      return const Center(child: Text('Plant not found.'));
    }
    if (plantState.status == PlantDetailsStatus.failure) {
      return Center(
        child: Text(plantState.errorMessage ?? 'Couldn\'t load this plant.'),
      );
    }
    final details = BlocBuilder<ObservationDetailsBloc, ObservationDetailsState>(
      builder: (context, state) => switch (state.status) {
        ObservationDetailsStatus.initial || ObservationDetailsStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        ObservationDetailsStatus.notFound => const Center(
          child: Text('Observation not found.'),
        ),
        ObservationDetailsStatus.failure => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage ?? 'Couldn\'t load this observation.'),
              OutlinedButton.icon(
                onPressed: () => context.read<ObservationDetailsBloc>().add(
                  ObservationDetailsWatchRequested(plantId, observationId),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
        ObservationDetailsStatus.loaded => SingleChildScrollView(
          key: const ValueKey('observation-details-page'),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to history',
                        onPressed: () =>
                            context.go(AppRoutes.observationHistory(plantId)),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          'Observation • ${plantDateLabel(state.observation!.createdAt)}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ObservationResultView(observation: state.observation!),
                  const SizedBox(height: 8),
                  Text(
                    'Model: ${state.observation!.modelName ?? 'Unknown'} • Source: client-originated Firebase AI output',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go(
                          AppRoutes.diagnoseObservation(plantId, observationId),
                        ),
                        icon: const Icon(Icons.health_and_safety_outlined),
                        label: const Text('Generate grounded diagnosis'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go(
                          AppRoutes.diagnosisHistory(plantId, observationId),
                        ),
                        icon: const Icon(Icons.history),
                        label: const Text('Diagnosis history'),
                      ),
                    ],
                  ),
                  if (enableKnowledgeRetrieval) ...[
                    const SizedBox(height: 24),
                    KnowledgeRetrievalPanel(
                      plant: plantState.plant!,
                      observation: state.observation!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      },
    );
    if (!enableKnowledgeRetrieval) return details;
    return BlocListener<KnowledgeRetrievalBloc, KnowledgeRetrievalState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == KnowledgeRetrievalStatus.candidateConflict,
      listener: (context, state) => _showPlantChoice(context, state.candidates),
      child: details,
    );
  }

  Future<void> _showPlantChoice(
    BuildContext context,
    List<String> candidates,
  ) async {
    final selection = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose the plant for this retrieval'),
        content: const Text(
          'The saved plant profile and image observation disagree. Your choice will not change the saved profile or observation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ...candidates.map(
            (key) => FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(key),
              child: Text('Use ${SupportedPlants.labels[key] ?? key}'),
            ),
          ),
        ],
      ),
    );
    if (selection != null && context.mounted) {
      context.read<KnowledgeRetrievalBloc>().add(
        KnowledgePlantCandidateSelected(selection),
      );
    }
  }
}
