import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_history_bloc.dart';

class FertilizerAssessmentHistoryPage extends StatelessWidget {
  const FertilizerAssessmentHistoryPage({required this.plantId, super.key});
  final String plantId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fertilizer assessment history')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.go(AppRoutes.newFertilizerAssessment(plantId)),
      icon: const Icon(Icons.eco_outlined),
      label: const Text('Assess'),
    ),
    body:
        BlocBuilder<
          FertilizerAssessmentHistoryBloc,
          FertilizerAssessmentHistoryState
        >(
          builder: (context, state) {
            if (state.status == FertilizerAssessmentHistoryStatus.initial ||
                state.status == FertilizerAssessmentHistoryStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == FertilizerAssessmentHistoryStatus.failure) {
              return _Message(
                message:
                    state.errorMessage ??
                    'Couldn’t load fertilizer assessments.',
                action: () => context
                    .read<FertilizerAssessmentHistoryBloc>()
                    .add(FertilizerAssessmentHistoryWatchRequested(plantId)),
              );
            }
            if (state.items.isEmpty) {
              return const _Message(message: 'No fertilizer assessments yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return Card(
                  child: ListTile(
                    key: ValueKey('fertilizer-assessment-${item.id}'),
                    leading: const Icon(Icons.eco_outlined),
                    title: Text(item.guidance.title),
                    subtitle: Text(
                      item.createdAt?.toLocal().toString() ?? 'Saving…',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(
                      AppRoutes.fertilizerAssessmentDetails(plantId, item.id),
                    ),
                  ),
                );
              },
            );
          },
        ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.action});
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: action, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}
