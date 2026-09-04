import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/observation_history_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/widgets/observation_result_view.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/widgets/plant_labels.dart';

class ObservationHistoryPage extends StatelessWidget {
  const ObservationHistoryPage({required this.plantId, super.key});
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
    return BlocBuilder<ObservationHistoryBloc, ObservationHistoryState>(
      builder: (context, state) => SingleChildScrollView(
        key: const ValueKey('observation-history-page'),
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
                      tooltip: 'Back to plant',
                      onPressed: () =>
                          context.go(AppRoutes.plantDetails(plantId)),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        'Observation history',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          context.go(AppRoutes.observePlant(plantId)),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('New observation'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                switch (state.status) {
                  ObservationHistoryStatus.initial ||
                  ObservationHistoryStatus.loading => const Center(
                    child: CircularProgressIndicator(
                      key: ValueKey('observation-history-loading'),
                    ),
                  ),
                  ObservationHistoryStatus.failure => Center(
                    child: Column(
                      children: [
                        Text(
                          state.errorMessage ?? 'Couldn\'t load observations.',
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('retry-observation-history'),
                          onPressed: () => context
                              .read<ObservationHistoryBloc>()
                              .add(ObservationHistoryWatchRequested(plantId)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                  ObservationHistoryStatus.loaded
                      when state.observations.isEmpty =>
                    const Card(
                      key: ValueKey('observation-history-empty'),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No saved observations yet. Images are never stored, so history contains structured text only.',
                        ),
                      ),
                    ),
                  ObservationHistoryStatus.loaded => Column(
                    children: state.observations
                        .map(
                          (item) => Card(
                            child: ListTile(
                              key: ValueKey('observation-${item.id}'),
                              leading: const Icon(Icons.visibility_outlined),
                              title: Text(item.summary),
                              subtitle: Text(
                                '${plantDateLabel(item.createdAt)} • ${item.severity.label}'
                                '${item.possibleIdentification.commonName == null ? '' : ' • Possible ${item.possibleIdentification.commonName}'}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go(
                                AppRoutes.observationDetails(plantId, item.id),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
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
