import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/soil_check/domain/entities/soil_check.dart';
import 'package:plantcare_ai/features/soil_check/presentation/bloc/soil_check_bloc.dart';
import 'package:plantcare_ai/features/soil_check/presentation/widgets/watering_guidance_view.dart';

class NewSoilCheckPage extends StatelessWidget {
  const NewSoilCheckPage({required this.plantId, super.key});
  final String plantId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Check soil')),
    body: BlocBuilder<SoilCheckBloc, SoilCheckState>(
      builder: (context, state) {
        if (state.status == SoilCheckStatus.initial ||
            state.status == SoilCheckStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.plant == null) {
          return _Message(
            message: state.errorMessage ?? 'Plant not found.',
            onRetry: () =>
                context.read<SoilCheckBloc>().add(SoilCheckStarted(plantId)),
          );
        }
        final busy =
            state.status == SoilCheckStatus.calculating ||
            state.status == SoilCheckStatus.saving;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Manual finger test',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check approximately 2–3 cm below the surface. Avoid judging only by the top surface. This is a qualitative check—not a numeric sensor measurement. For large pots or ground plants, check more than one spot when practical.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'How does the soil feel?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...SoilMoistureLevel.values.map(
                    (level) => Card(
                      color: state.moistureLevel == level
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      child: ListTile(
                        key: ValueKey('moisture-${level.value}'),
                        enabled: !busy,
                        selected: state.moistureLevel == level,
                        leading: Icon(
                          state.moistureLevel == level
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(level.label),
                        subtitle: Text(level.description),
                        onTap: busy
                            ? null
                            : () => context.read<SoilCheckBloc>().add(
                                SoilCheckMoistureSelected(level),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('calculate-soil-check'),
                    onPressed: busy || state.moistureLevel == null
                        ? null
                        : () => context.read<SoilCheckBloc>().add(
                            SoilCheckSubmitted(checkTime: DateTime.now()),
                          ),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.water_drop_outlined),
                    label: Text(busy ? 'Checking…' : 'Get watering guidance'),
                  ),
                  if (state.guidance != null) ...[
                    const SizedBox(height: 20),
                    WateringGuidanceView(
                      guidance: state.guidance!,
                      sources: state.sources,
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (state.saveRetryAvailable) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.read<SoilCheckBloc>().add(
                        const SoilCheckSaveRetried(),
                      ),
                      child: const Text('Retry save'),
                    ),
                  ],
                  if (state.status == SoilCheckStatus.saved) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () =>
                          context.go(AppRoutes.soilCheckHistory(plantId)),
                      child: const Text('View soil-check history'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
