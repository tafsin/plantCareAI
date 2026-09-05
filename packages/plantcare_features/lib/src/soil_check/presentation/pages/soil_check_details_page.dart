import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';
import 'package:plantcare_features/src/soil_check/presentation/bloc/soil_check_details_bloc.dart';
import 'package:plantcare_features/src/soil_check/presentation/widgets/soil_check_labels.dart';
import 'package:plantcare_features/src/soil_check/presentation/widgets/watering_guidance_view.dart';

class SoilCheckDetailsPage extends StatelessWidget {
  const SoilCheckDetailsPage({
    required this.plantId,
    required this.soilCheckId,
    super.key,
  });
  final String plantId;
  final String soilCheckId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Soil-check details')),
    body: BlocBuilder<SoilCheckDetailsBloc, SoilCheckDetailsState>(
      builder: (context, state) => switch (state.status) {
        SoilCheckDetailsStatus.initial || SoilCheckDetailsStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        SoilCheckDetailsStatus.notFound => const Center(
          child: Text('Soil check not found.'),
        ),
        SoilCheckDetailsStatus.failure => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage ?? 'Couldn\'t load this soil check.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.read<SoilCheckDetailsBloc>().add(
                  SoilCheckDetailsWatchRequested(plantId, soilCheckId),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        SoilCheckDetailsStatus.loaded => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    state.item!.moistureLevel.label,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    state.item!.createdAt?.toLocal().toString() ??
                        'Timestamp pending',
                  ),
                  const SizedBox(height: 16),
                  WateringGuidanceView(
                    guidance: state.item!.guidance,
                    sources: state.sources,
                  ),
                  if (state.item!.suggestedCheckAt case final dueAt?) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go(
                        AppRoutes.newReminder(
                          plantId,
                          source: ReminderSource.soilCheckSuggestion,
                          referenceId: soilCheckId,
                          suggestedAt: dueAt,
                        ),
                      ),
                      icon: const Icon(Icons.add_alert),
                      label: const Text('Review suggested reminder'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Environment snapshot: ${state.item!.environmentSnapshot.name}',
                  ),
                  Text(
                    'Growing medium snapshot: ${state.item!.growingMediumSnapshot.name}',
                  ),
                ],
              ),
            ),
          ),
        ),
      },
    ),
  );
}
