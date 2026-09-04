import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminders_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RemindersBloc?>();
    return Center(
      key: const ValueKey('home-page'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.eco_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to PlantCare AI',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'A healthy home for your plant collection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (bloc != null)
              BlocBuilder<RemindersBloc, RemindersState>(
                builder: (context, state) {
                  final groups = state.categorized(DateTime.now());
                  final overdue = groups[ReminderBucket.overdue]!.length;
                  final soil = groups[ReminderBucket.today]!
                      .where((item) => item.type == ReminderType.soilCheck)
                      .length;
                  final fertilizer = groups[ReminderBucket.upcoming]!
                      .where(
                        (item) => item.type == ReminderType.fertilizerReview,
                      )
                      .length;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _DashboardCard(
                        label: 'Overdue reminders',
                        count: overdue,
                      ),
                      _DashboardCard(
                        label: 'Soil checks due today',
                        count: soil,
                      ),
                      _DashboardCard(
                        label: 'Upcoming fertilizer reviews',
                        count: fertilizer,
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.plants),
                  icon: const Icon(Icons.local_florist),
                  label: const Text('My Plants'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.reminders),
                  icon: const Icon(Icons.notifications),
                  label: const Text('Reminders'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.label, required this.count});
  static const _size = Size(190, 128);

  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      width: _size.width,
      height: _size.height,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$count', style: Theme.of(context).textTheme.headlineMedium),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
