import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/plant_diagnosis_bloc.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/widgets/diagnosis_result_view.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/observation_details_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';

class PlantDiagnosisPage extends StatelessWidget {
  const PlantDiagnosisPage({
    required this.plantId,
    required this.observationId,
    super.key,
  });

  final String plantId;
  final String observationId;

  @override
  Widget build(BuildContext context) {
    final plantState = context.watch<PlantDetailsBloc>().state;
    final observationState = context.watch<ObservationDetailsBloc>().state;
    if (plantState.status == PlantDetailsStatus.initial ||
        plantState.status == PlantDetailsStatus.loading ||
        observationState.status == ObservationDetailsStatus.initial ||
        observationState.status == ObservationDetailsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (plantState.status == PlantDetailsStatus.notFound ||
        observationState.status == ObservationDetailsStatus.notFound) {
      return const Center(child: Text('Plant observation not found.'));
    }
    if (plantState.status == PlantDetailsStatus.failure ||
        observationState.status == ObservationDetailsStatus.failure) {
      return const Center(child: Text('Couldn’t load this plant observation.'));
    }
    final plant = plantState.plant!;
    final observation = observationState.observation!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: BlocBuilder<PlantDiagnosisBloc, PlantDiagnosisState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go(
                        AppRoutes.observationDetails(plantId, observationId),
                      ),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        'Grounded diagnosis',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(
                        AppRoutes.diagnosisHistory(plantId, observationId),
                      ),
                      child: const Text('History'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.status == PlantDiagnosisStatus.initial)
                  FilledButton.icon(
                    key: const ValueKey('generate-grounded-diagnosis'),
                    onPressed: () => context.read<PlantDiagnosisBloc>().add(
                      PlantDiagnosisRequested(
                        plantId: plantId,
                        observationId: observationId,
                        plant: plant,
                        observation: observation,
                      ),
                    ),
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: const Text('Generate grounded diagnosis'),
                  ),
                if (state.status == PlantDiagnosisStatus.retrievingEvidence)
                  const _Progress(message: 'Retrieving relevant evidence…'),
                if (state.status == PlantDiagnosisStatus.generating)
                  const _Progress(message: 'Generating a cautious diagnosis…'),
                if (state.status == PlantDiagnosisStatus.saving) ...[
                  const _Progress(message: 'Saving diagnosis…'),
                  if (state.diagnosis != null)
                    DiagnosisResultView(
                      diagnosis: state.diagnosis!,
                      retrieval: state.retrieval,
                    ),
                ],
                if (state.status ==
                    PlantDiagnosisStatus.conflictSelectionRequired)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose the plant',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text(
                            'The saved profile and AI observation disagree. Select the identity to use for this diagnosis.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: state.candidates
                                .map(
                                  (candidate) => FilledButton.tonal(
                                    onPressed: () =>
                                        context.read<PlantDiagnosisBloc>().add(
                                          DiagnosisPlantCandidateSelected(
                                            candidate,
                                          ),
                                        ),
                                    child: Text(
                                      'Use ${SupportedPlants.labels[candidate] ?? candidate}',
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (state.status == PlantDiagnosisStatus.insufficientEvidence)
                  _Message(
                    title: 'Insufficient evidence',
                    message: 'No knowledge result met the existing relevance threshold. Gemini was not called.',
                    action: () => context.read<PlantDiagnosisBloc>().add(
                      const PlantDiagnosisRetryRequested(),
                    ),
                  ),
                if (state.status == PlantDiagnosisStatus.failure) ...[
                  if (state.diagnosis != null)
                    DiagnosisResultView(
                      diagnosis: state.diagnosis!,
                      retrieval: state.retrieval,
                    ),
                  _Message(
                    title: state.saveRetryAvailable
                        ? 'Diagnosis not saved'
                        : 'Diagnosis unavailable',
                    message: state.errorMessage ?? 'Please try again.',
                    action: () => context.read<PlantDiagnosisBloc>().add(
                      state.saveRetryAvailable
                          ? const PlantDiagnosisSaveRetryRequested()
                          : const PlantDiagnosisRetryRequested(),
                    ),
                    actionLabel: state.saveRetryAvailable
                        ? 'Retry save'
                        : 'Try again',
                  ),
                ],
                if (state.status == PlantDiagnosisStatus.success)
                  DiagnosisResultView(
                    diagnosis: state.diagnosis!,
                    retrieval: state.retrieval,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(message),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.message,
    required this.action,
    this.actionLabel = 'Try again',
  });
  final String title;
  final String message;
  final VoidCallback action;
  final String actionLabel;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: action, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
