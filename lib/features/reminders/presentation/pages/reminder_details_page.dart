import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/navigation/presentation/app_routes.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminder_details_bloc.dart';
import 'package:plantcare_domain/reminders.dart';

class ReminderDetailsPage extends StatelessWidget {
  const ReminderDetailsPage({required this.plantId, super.key});
  final String plantId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reminder details')),
    body: BlocBuilder<ReminderDetailsBloc, ReminderDetailsState>(
      builder: (context, state) => switch (state.status) {
        ReminderDetailsStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        ReminderDetailsStatus.notFound => const Center(
          child: Text('Reminder not found.'),
        ),
        ReminderDetailsStatus.failure => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage ?? 'Couldn’t load reminder.'),
              OutlinedButton(
                onPressed: () => context.read<ReminderDetailsBloc>().add(
                  const ReminderDetailsWatchRequested(),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        _ => _Loaded(
          item: state.item!,
          saving: state.status == ReminderDetailsStatus.saving,
        ),
      },
    ),
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.item, required this.saving});
  final Reminder item;
  final bool saving;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(item.dueAt.toLocal().toString()),
      Text('Status: ${item.status.name}'),
      if (item.note != null) ...[const SizedBox(height: 16), Text(item.note!)],
      const SizedBox(height: 24),
      if (!kIsWeb && item.status == ReminderStatus.active) ...[
        const Text(
          'Device delivery is optional. Retrying may ask for notification permission; the reminder remains available in-app if permission is denied.',
        ),
        const SizedBox(height: 12),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.plantDetails(item.plantId)),
            icon: const Icon(Icons.local_florist),
            label: const Text('View plant'),
          ),
          if (item.status == ReminderStatus.active) ...[
            FilledButton(
              onPressed: saving
                  ? null
                  : () => context.read<ReminderDetailsBloc>().add(
                      const ReminderStatusRequested(ReminderStatus.completed),
                    ),
              child: const Text('Complete'),
            ),
            OutlinedButton(
              onPressed: saving
                  ? null
                  : () => context.read<ReminderDetailsBloc>().add(
                      const ReminderStatusRequested(ReminderStatus.cancelled),
                    ),
              child: const Text('Cancel'),
            ),
            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () => context.read<ReminderDetailsBloc>().add(
                        const ReminderLocalSchedulingRetried(),
                      ),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Retry device notification'),
              ),
          ] else
            FilledButton(
              onPressed: saving ? null : () => _reschedule(context),
              child: const Text('Reschedule and reactivate'),
            ),
        ],
      ),
    ],
  );
  Future<void> _reschedule(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time != null && context.mounted) {
      context.read<ReminderDetailsBloc>().add(
        ReminderStatusRequested(
          ReminderStatus.active,
          dueAt: DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
        ),
      );
    }
  }
}
