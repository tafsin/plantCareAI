import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/services/latest_care_logs.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_history_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/widgets/care_log_labels.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_history_bloc.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plants_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/widgets/plant_labels.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminders_bloc.dart';
import 'package:plantcare_ai/features/soil_check/domain/entities/soil_check.dart';
import 'package:plantcare_ai/features/soil_check/presentation/bloc/soil_check_history_bloc.dart';

class PlantDetailsPage extends StatelessWidget {
  const PlantDetailsPage({
    required this.plantId,
    this.enableSoilChecks = false,
    this.enableCareLogs = false,
    this.enableFertilizerAssessments = false,
    this.enableReminders = false,
    super.key,
  });
  final String plantId;
  final bool enableSoilChecks;
  final bool enableCareLogs;
  final bool enableFertilizerAssessments;
  final bool enableReminders;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlantsBloc, PlantsState>(
      listenWhen: (previous, current) =>
          current.actionRevision > previous.actionRevision,
      listener: (context, state) {
        if (state.deletedPlantId == plantId) {
          context.go(AppRoutes.plants);
        } else if (state.deleteFailureMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.deleteFailureMessage!)));
        }
      },
      child: BlocBuilder<PlantDetailsBloc, PlantDetailsState>(
        builder: (context, state) => switch (state.status) {
          PlantDetailsStatus.initial ||
          PlantDetailsStatus.loading => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('plant-details-loading'),
            ),
          ),
          PlantDetailsStatus.notFound => const _DetailsMessage(
            key: ValueKey('plant-not-found'),
            title: 'Plant not found',
            message: 'This plant may have been deleted or is unavailable.',
          ),
          PlantDetailsStatus.failure => _DetailsFailure(
            plantId: plantId,
            message: state.errorMessage,
          ),
          PlantDetailsStatus.loaded => _PlantDetails(
            plant: state.plant!,
            enableSoilChecks: enableSoilChecks,
            enableCareLogs: enableCareLogs,
            enableFertilizerAssessments: enableFertilizerAssessments,
            enableReminders: enableReminders,
          ),
        },
      ),
    );
  }
}

class _PlantDetails extends StatelessWidget {
  const _PlantDetails({
    required this.plant,
    required this.enableSoilChecks,
    required this.enableCareLogs,
    required this.enableFertilizerAssessments,
    required this.enableReminders,
  });
  final Plant plant;
  final bool enableSoilChecks;
  final bool enableCareLogs;
  final bool enableFertilizerAssessments;
  final bool enableReminders;

  @override
  Widget build(BuildContext context) {
    final deleting = context.select<PlantsBloc, bool>(
      (bloc) => bloc.state.deletingPlantIds.contains(plant.id),
    );
    return SingleChildScrollView(
      key: const ValueKey('plant-details-loaded'),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Back to plants',
                    onPressed: () => context.go(AppRoutes.plants),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plant.commonName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (plant.scientificName case final String name)
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('edit-plant'),
                    tooltip: 'Edit plant',
                    onPressed: deleting
                        ? null
                        : () => context.go(AppRoutes.editPlant(plant.id)),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    key: const ValueKey('delete-plant'),
                    tooltip: 'Delete plant',
                    onPressed: deleting ? null : () => _confirmDelete(context),
                    icon: deleting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('observe-plant'),
                    onPressed: () =>
                        context.go(AppRoutes.observePlant(plant.id)),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Observe plant'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('observation-history'),
                    onPressed: () =>
                        context.go(AppRoutes.observationHistory(plant.id)),
                    icon: const Icon(Icons.history),
                    label: const Text('Observation history'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (enableSoilChecks) ...[
                _SoilSection(plantId: plant.id),
                const SizedBox(height: 16),
              ],
              if (enableCareLogs) ...[
                _CareSection(plantId: plant.id),
                const SizedBox(height: 16),
              ],
              if (enableFertilizerAssessments && enableCareLogs) ...[
                _FertilizerSection(plantId: plant.id),
                const SizedBox(height: 16),
              ],
              if (enableReminders) ...[
                BlocBuilder<RemindersBloc, RemindersState>(
                  builder: (context, state) {
                    final active = state.items
                        .where((item) => item.status == ReminderStatus.active)
                        .length;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Care reminders',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              active == 0
                                  ? 'No active reminders.'
                                  : '$active active reminder${active == 1 ? '' : 's'}.',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => context.go(
                                    AppRoutes.newReminder(plant.id),
                                    extra: plant.commonName,
                                  ),
                                  icon: const Icon(Icons.add_alert),
                                  label: const Text('New reminder'),
                                ),
                                OutlinedButton(
                                  onPressed: () => context.go(
                                    AppRoutes.plantReminders(plant.id),
                                  ),
                                  child: const Text('View reminders'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 24,
                    children: [
                      _Field(
                        label: 'Environment',
                        value: plant.environment.label,
                      ),
                      _Field(
                        label: 'Growing medium',
                        value: plant.growingMedium.label,
                      ),
                      if (plant.potSizeLiters case final double size)
                        _Field(label: 'Pot size', value: '$size L'),
                      _Field(label: 'Sunlight', value: plant.sunlight.label),
                      _Field(
                        label: 'Growth stage',
                        value: plant.growthStage.label,
                      ),
                      _Field(
                        label: 'Created',
                        value: plantDateLabel(plant.createdAt),
                      ),
                      _Field(
                        label: 'Updated',
                        value: plantDateLabel(plant.updatedAt),
                      ),
                    ],
                  ),
                ),
              ),
              if (plant.notes case final String notes) ...[
                const SizedBox(height: 20),
                Text('Notes', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(notes),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete plant?'),
        content: Text('Delete ${plant.commonName}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-plant'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<PlantsBloc>().add(PlantDeleteRequested(plant.id));
    }
  }
}

class _FertilizerSection extends StatelessWidget {
  const _FertilizerSection({required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('fertilizer-section'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child:
          BlocBuilder<
            FertilizerAssessmentHistoryBloc,
            FertilizerAssessmentHistoryState
          >(
            builder: (context, state) {
              final latestAssessment = state.items.isEmpty
                  ? null
                  : state.items.first;
              final latestFertilizer = latestCareLogs(
                context.watch<CareHistoryBloc>().state.logs,
              ).fertilizing;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fertilizer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (state.status ==
                          FertilizerAssessmentHistoryStatus.loading &&
                      state.items.isEmpty)
                    const LinearProgressIndicator()
                  else if (state.status ==
                          FertilizerAssessmentHistoryStatus.failure &&
                      state.items.isEmpty)
                    Text(
                      state.errorMessage ??
                          'Couldn’t load fertilizer guidance.',
                    )
                  else
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        _Field(
                          label: 'Last fertilized',
                          value: latestFertilizer == null
                              ? 'No fertilizer recorded'
                              : careDateLabel(latestFertilizer.occurredAt),
                        ),
                        _Field(
                          label: 'Latest guidance',
                          value:
                              latestAssessment?.guidance.title ??
                              'No assessment recorded',
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => context.go(
                          AppRoutes.newFertilizerAssessment(plantId),
                        ),
                        icon: const Icon(Icons.eco_outlined),
                        label: const Text('Check fertilizer guidance'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go(
                          AppRoutes.newCareLog(
                            plantId,
                            CareLogType.fertilizing,
                          ),
                        ),
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('Log fertilizer'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go(
                          AppRoutes.fertilizerAssessmentHistory(plantId),
                        ),
                        icon: const Icon(Icons.history),
                        label: const Text('View assessment history'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
    ),
  );
}

class _CareSection extends StatelessWidget {
  const _CareSection({required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('care-section'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: BlocBuilder<CareHistoryBloc, CareHistoryState>(
        builder: (context, state) {
          final latest = latestCareLogs(state.logs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Care', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (state.status == CareHistoryStatus.loading &&
                  state.logs.isEmpty)
                const LinearProgressIndicator()
              else if (state.status == CareHistoryStatus.failure &&
                  state.logs.isEmpty)
                Text(state.errorMessage ?? 'Couldn\'t load care history.')
              else
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _Field(
                      label: 'Last watered',
                      value: latest.watering == null
                          ? 'No watering recorded'
                          : careDateLabel(latest.watering!.occurredAt),
                    ),
                    _Field(
                      label: 'Last fertilized',
                      value: latest.fertilizing == null
                          ? 'No fertilizer recorded'
                          : careDateLabel(latest.fertilizing!.occurredAt),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => context.go(
                      AppRoutes.newCareLog(plantId, CareLogType.watering),
                    ),
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('Log watering'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go(
                      AppRoutes.newCareLog(plantId, CareLogType.fertilizing),
                    ),
                    icon: const Icon(Icons.eco_outlined),
                    label: const Text('Log fertilizer'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.careHistory(plantId)),
                    icon: const Icon(Icons.history),
                    label: const Text('View care history'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _SoilSection extends StatelessWidget {
  const _SoilSection({required this.plantId});
  final String plantId;
  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('soil-section'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: BlocBuilder<SoilCheckHistoryBloc, SoilCheckHistoryState>(
        builder: (context, state) {
          final latest = state.items.isEmpty ? null : state.items.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Soil', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (state.status == SoilCheckHistoryStatus.loading)
                const LinearProgressIndicator()
              else if (state.status == SoilCheckHistoryStatus.failure)
                Text(
                  state.errorMessage ?? 'Couldn\'t load the latest soil check.',
                )
              else if (latest == null)
                const Text('No manual soil checks yet.')
              else
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _Field(
                      label: 'Latest moisture',
                      value: latest.moistureLevel.label,
                    ),
                    _Field(
                      label: 'Recommendation',
                      value: latest.guidance.title,
                    ),
                    _Field(
                      label: 'Last checked',
                      value: plantDateLabel(latest.createdAt),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.go(AppRoutes.newSoilCheck(plantId)),
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('Check soil'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.go(AppRoutes.soilCheckHistory(plantId)),
                    icon: const Icon(Icons.history),
                    label: const Text('View history'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _DetailsMessage extends StatelessWidget {
  const _DetailsMessage({
    required this.title,
    required this.message,
    super.key,
  });
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.plants),
          child: const Text('Back to plants'),
        ),
      ],
    ),
  );
}

class _DetailsFailure extends StatelessWidget {
  const _DetailsFailure({required this.plantId, this.message});
  final String plantId;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message ?? 'Couldn\'t load this plant.'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.read<PlantDetailsBloc>().add(
            PlantDetailsWatchRequested(plantId),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
