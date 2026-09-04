import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/navigation/presentation/app_routes.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/diagnosis_history_bloc.dart';

class DiagnosisHistoryPage extends StatelessWidget {
  const DiagnosisHistoryPage({
    required this.plantId,
    required this.observationId,
    super.key,
  });
  final String plantId;
  final String observationId;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DiagnosisHistoryBloc, DiagnosisHistoryState>(
        builder: (context, state) => switch (state.status) {
          DiagnosisHistoryStatus.initial || DiagnosisHistoryStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          DiagnosisHistoryStatus.failure => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.errorMessage ?? 'Couldn’t load diagnosis history.'),
                OutlinedButton(
                  onPressed: () => context.read<DiagnosisHistoryBloc>().add(
                    DiagnosisHistoryWatchRequested(plantId, observationId),
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          DiagnosisHistoryStatus.loaded => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go(
                            AppRoutes.observationDetails(
                              plantId,
                              observationId,
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Text(
                            'Diagnosis history',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (state.items.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No saved diagnoses yet.'),
                        ),
                      )
                    else
                      ...state.items.map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item.summary),
                            subtitle: Text(
                              'AI-assisted, not guaranteed • ${item.modelName}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go(
                              AppRoutes.diagnosisDetails(
                                plantId,
                                observationId,
                                item.id,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        },
      );
}
