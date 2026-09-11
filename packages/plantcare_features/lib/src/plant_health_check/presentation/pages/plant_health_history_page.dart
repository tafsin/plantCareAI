import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_history_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/widgets/plant_labels.dart';

class PlantHealthHistoryPage extends StatelessWidget {
  const PlantHealthHistoryPage({required this.plantId, super.key});

  final String plantId;

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
        child: Text(plantState.errorMessage ?? 'Couldn\'t load plant.'),
      );
    }
    return BlocBuilder<PlantHealthHistoryBloc, PlantHealthHistoryState>(
      builder: (context, state) => SingleChildScrollView(
        key: const ValueKey('plant-health-history-page'),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to plant',
                      onPressed: () =>
                          context.go(AppRoutes.plantDetails(plantId)),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        'Health history',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          context.go(AppRoutes.healthCheck(plantId)),
                      icon: const Icon(Icons.health_and_safety_outlined),
                      label: const Text('Check health'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                switch (state.status) {
                  PlantHealthHistoryStatus.initial ||
                  PlantHealthHistoryStatus.loading => const Center(
                    child: CircularProgressIndicator(
                      key: ValueKey('health-history-loading'),
                    ),
                  ),
                  PlantHealthHistoryStatus.failure => _Failure(
                    message: state.errorMessage,
                    onRetry: () => context.read<PlantHealthHistoryBloc>().add(
                      PlantHealthHistoryWatchRequested(plantId),
                    ),
                  ),
                  PlantHealthHistoryStatus.loaded when state.entries.isEmpty =>
                    const Card(
                      key: ValueKey('health-history-empty'),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No health checks yet. Saved checks include structured findings and assessments; a processed local photo may also be available on this device.',
                        ),
                      ),
                    ),
                  PlantHealthHistoryStatus.loaded => LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 720;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: state.entries
                            .map(
                              (entry) => SizedBox(
                                width: wide
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth,
                                child: _HistoryCard(
                                  plantId: plantId,
                                  entry: entry,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.plantId, required this.entry});

  final String plantId;
  final PlantHealthHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final diagnosis = entry.latestDiagnosis;
    return Card(
      child: ListTile(
        key: ValueKey('health-entry-${entry.observation.id}'),
        leading: Icon(_stateIcon(entry.assessmentState)),
        title: Text(entry.observation.summary),
        subtitle: Text(
          '${plantDateLabel(entry.observation.createdAt)}\n'
          '${_stateLabel(entry.assessmentState)}'
          '${diagnosis == null ? '' : '\n${diagnosis.summary}'}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(
          AppRoutes.healthAssessment(plantId, entry.observation.id),
        ),
      ),
    );
  }

  IconData _stateIcon(PlantHealthHistoryAssessmentState state) =>
      switch (state) {
        PlantHealthHistoryAssessmentState.complete =>
          Icons.check_circle_outline,
        PlantHealthHistoryAssessmentState.needsAnotherPhoto =>
          Icons.add_a_photo_outlined,
        PlantHealthHistoryAssessmentState.insufficientEvidence =>
          Icons.info_outline,
        PlantHealthHistoryAssessmentState.incomplete => Icons.pending_outlined,
      };

  String _stateLabel(PlantHealthHistoryAssessmentState state) =>
      switch (state) {
        PlantHealthHistoryAssessmentState.complete => 'Complete',
        PlantHealthHistoryAssessmentState.needsAnotherPhoto =>
          'Needs another photo',
        PlantHealthHistoryAssessmentState.insufficientEvidence =>
          'Insufficient evidence',
        PlantHealthHistoryAssessmentState.incomplete => 'Assessment incomplete',
      };
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(message ?? 'Couldn\'t load health history.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('retry-health-history'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
