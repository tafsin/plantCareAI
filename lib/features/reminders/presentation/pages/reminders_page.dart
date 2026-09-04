import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plants_bloc.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminders_bloc.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({this.plantId, super.key});
  final String? plantId;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RemindersBloc, RemindersState>(
        builder: (context, state) {
          if (state.status == RemindersStatus.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == RemindersStatus.failure && state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Couldn’t load reminders.'),
                  OutlinedButton(
                    onPressed: () => context.read<RemindersBloc>().add(
                      RemindersWatchRequested(plantId),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          final groups = state.categorized(DateTime.now());
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plantId == null ? 'Care reminders' : 'Plant reminders',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add_alert),
                    label: const Text('New reminder'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (kIsWeb)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Web reminders appear while you use PlantCare AI. Background notifications are not available in this version.',
                    ),
                  ),
                ),
              if (state.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: Text(
                      'No reminders yet. Create one when you want to check or review plant care.',
                    ),
                  ),
                ),
              for (final entry in [
                (ReminderBucket.overdue, 'Overdue'),
                (ReminderBucket.today, 'Due today'),
                (ReminderBucket.upcoming, 'Upcoming'),
                (ReminderBucket.history, 'Completed/cancelled history'),
              ])
                _Section(title: entry.$2, items: groups[entry.$1]!),
            ],
          );
        },
      );
  void _create(BuildContext context) {
    final plants = context.read<PlantsBloc>().state.plants;
    if (plantId != null) {
      context.go(AppRoutes.newReminder(plantId!));
      return;
    }
    if (plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a plant before creating a reminder.'),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Choose a plant'),
        children: [
          for (final plant in plants)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialog);
                context.go(
                  AppRoutes.newReminder(plant.id),
                  extra: plant.commonName,
                );
              },
              child: Text(plant.commonName),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<Reminder> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Card(
          child: Column(
            children: [
              for (final item in items)
                ListTile(
                  leading: Icon(
                    item.type == ReminderType.soilCheck
                        ? Icons.water_drop_outlined
                        : Icons.eco_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.dueAt.toLocal()} • ${item.status.name}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    AppRoutes.reminderDetails(item.plantId, item.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
