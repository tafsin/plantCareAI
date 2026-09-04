import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_details_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/widgets/care_log_labels.dart';

class CareLogDetailsPage extends StatelessWidget {
  const CareLogDetailsPage({required this.plantId, super.key});
  final String plantId;

  @override
  Widget build(BuildContext context) =>
      BlocListener<CareLogDetailsBloc, CareLogDetailsState>(
        listenWhen: (before, after) => before.status != after.status,
        listener: (context, state) {
          if (state.status == CareLogDetailsStatus.deleted) {
            context.go(AppRoutes.careHistory(plantId));
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Care log details')),
          body: BlocBuilder<CareLogDetailsBloc, CareLogDetailsState>(
            builder: (context, state) => switch (state.status) {
              CareLogDetailsStatus.initial || CareLogDetailsStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              CareLogDetailsStatus.notFound => const Center(
                child: Text('Care log not found.'),
              ),
              CareLogDetailsStatus.failure when state.log == null => _Failure(
                plantId: plantId,
                message: state.errorMessage,
              ),
              _ => _Details(
                log: state.log!,
                deleting: state.status == CareLogDetailsStatus.deleting,
                errorMessage: state.errorMessage,
              ),
            },
          ),
        ),
      );
}

class _Details extends StatelessWidget {
  const _Details({
    required this.log,
    required this.deleting,
    this.errorMessage,
  });
  final CareLog log;
  final bool deleting;
  final String? errorMessage;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  log is WateringLog
                      ? Icons.water_drop_outlined
                      : Icons.eco_outlined,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  careActionTitle(log),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _Row(
                  label: 'Occurred',
                  value: careDateTimeLabel(log.occurredAt),
                ),
                _Row(
                  label: log is WateringLog ? 'Method' : 'Form',
                  value: careMethodLabel(log),
                ),
                if (log case WateringLog(:final amountMl?))
                  _Row(label: 'Amount', value: '${amountMl.toString()} mL'),
                if (log case FertilizingLog(:final productName?))
                  _Row(label: 'Product name', value: productName),
                if (log case FertilizingLog(:final applicationNote?))
                  _Row(label: 'Application note', value: applicationNote),
                if (log.notes case final String notes)
                  _Row(label: 'Notes', value: notes),
                if (log.createdAt case final DateTime createdAt)
                  _Row(label: 'Recorded', value: careDateTimeLabel(createdAt)),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const ValueKey('delete-care-log'),
                  onPressed: deleting ? null : () => _confirmDelete(context),
                  icon: deleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(deleting ? 'Deleting…' : 'Delete log'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${careActionTitle(log).toLowerCase()} log?'),
        content: Text(
          'Delete the ${careActionTitle(log).toLowerCase()} action from ${careDateTimeLabel(log.occurredAt)}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CareLogDetailsBloc>().add(const CareLogDeleteRequested());
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.plantId, this.message});
  final String plantId;
  final String? message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message ?? 'Couldn\'t load this care log.'),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.read<CareLogDetailsBloc>().add(
            const CareLogDetailsRequested(),
          ),
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}
