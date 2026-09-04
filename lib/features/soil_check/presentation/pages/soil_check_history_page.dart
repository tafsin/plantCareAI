import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/soil_check/domain/entities/soil_check.dart';
import 'package:plantcare_ai/features/soil_check/presentation/bloc/soil_check_history_bloc.dart';

class SoilCheckHistoryPage extends StatelessWidget {
  const SoilCheckHistoryPage({required this.plantId, super.key});
  final String plantId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Soil-check history')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.go(AppRoutes.newSoilCheck(plantId)),
      icon: const Icon(Icons.water_drop_outlined),
      label: const Text('Check soil'),
    ),
    body: BlocBuilder<SoilCheckHistoryBloc, SoilCheckHistoryState>(
      builder: (context, state) => switch (state.status) {
        SoilCheckHistoryStatus.initial || SoilCheckHistoryStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        SoilCheckHistoryStatus.failure => _HistoryMessage(
          message: state.errorMessage ?? 'Couldn\'t load soil checks.',
          action: () => context.read<SoilCheckHistoryBloc>().add(
            SoilCheckHistoryWatchRequested(plantId),
          ),
        ),
        SoilCheckHistoryStatus.loaded when state.items.isEmpty =>
          const _HistoryMessage(
            message:
                'No soil checks yet. Use “Check soil” to record the first one.',
          ),
        SoilCheckHistoryStatus.loaded => ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = state.items[index];
            return Card(
              child: ListTile(
                key: ValueKey('soil-check-${item.id}'),
                leading: const Icon(Icons.water_drop_outlined),
                title: Text(
                  '${item.moistureLevel.label} — ${item.guidance.title}',
                ),
                subtitle: Text(
                  item.createdAt == null
                      ? 'Saving…'
                      : item.createdAt!.toLocal().toString(),
                ),
                onTap: () =>
                    context.go(AppRoutes.soilCheckDetails(plantId, item.id)),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        ),
      },
    ),
  );
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.message, this.action});
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
