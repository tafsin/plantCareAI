import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/navigation/presentation/app_routes.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/plant_observation_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/widgets/observation_result_view.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';

class PlantObservationPage extends StatelessWidget {
  const PlantObservationPage({required this.plantId, super.key});
  final String plantId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlantDetailsBloc, PlantDetailsState>(
      builder: (context, state) => switch (state.status) {
        PlantDetailsStatus.initial || PlantDetailsStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        PlantDetailsStatus.notFound => const _PageMessage(
          title: 'Plant not found',
          message: 'This plant may have been deleted or is unavailable.',
        ),
        PlantDetailsStatus.failure => _PageMessage(
          title: 'Couldn\'t load this plant',
          message: state.errorMessage ?? 'Please try again.',
        ),
        PlantDetailsStatus.loaded => _ObservationWorkflow(
          plantId: plantId,
          plant: state.plant!,
        ),
      },
    );
  }
}

class _ObservationWorkflow extends StatelessWidget {
  const _ObservationWorkflow({required this.plantId, required this.plant});
  final String plantId;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlantObservationBloc, PlantObservationState>(
      builder: (context, state) {
        return SingleChildScrollView(
          key: const ValueKey('plant-observation-page'),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to plant',
                        onPressed: () =>
                            context.go(AppRoutes.plantDetails(plantId)),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          'Observe ${plant.commonName}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.go(AppRoutes.observationHistory(plantId)),
                        child: const Text('History'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _PhotoGuidance(),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('pick-gallery'),
                        onPressed: state.busy
                            ? null
                            : () => context.read<PlantObservationBloc>().add(
                                const PlantObservationImageRequested(
                                  PlantImageSource.gallery,
                                ),
                              ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          state.image == null
                              ? 'Choose photo'
                              : 'Replace photo',
                        ),
                      ),
                      if (context.read<PlantObservationBloc>().supportsCamera)
                        OutlinedButton.icon(
                          key: const ValueKey('pick-camera'),
                          onPressed: state.busy
                              ? null
                              : () => context.read<PlantObservationBloc>().add(
                                  const PlantObservationImageRequested(
                                    PlantImageSource.camera,
                                  ),
                                ),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Use camera'),
                        )
                      else
                        const Tooltip(
                          message: 'Browser camera capture is not offered because support varies. Choose an existing file instead.',
                          child: Chip(label: Text('Web camera unavailable')),
                        ),
                    ],
                  ),
                  if (state.status == PlantObservationStatus.processingImage)
                    const _Progress(label: 'Preparing image…'),
                  if (state.image != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        state.image!.bytes,
                        key: const ValueKey('image-preview'),
                        height: 320,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('remove-image'),
                        onPressed: state.busy
                            ? null
                            : () => context.read<PlantObservationBloc>().add(
                                const PlantObservationImageRemoved(),
                              ),
                        icon: const Icon(Icons.close),
                        label: const Text('Remove'),
                      ),
                    ),
                    const _PrivacyDisclosure(),
                    CheckboxListTile(
                      key: const ValueKey('privacy-consent'),
                      contentPadding: EdgeInsets.zero,
                      value: state.consented,
                      onChanged: state.busy
                          ? null
                          : (value) => context.read<PlantObservationBloc>().add(
                              PlantObservationConsentChanged(value ?? false),
                            ),
                      title: const Text(
                        'I understand and want to send this image for analysis.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    FilledButton.icon(
                      key: const ValueKey('analyze-image'),
                      onPressed: state.canAnalyze
                          ? () => context.read<PlantObservationBloc>().add(
                              PlantObservationAnalysisRequested(
                                plantId: plantId,
                                context: PlantObservationContext(
                                  commonName: plant.commonName,
                                  scientificName: plant.scientificName,
                                  environment: plant.environment.name,
                                  growthStage: plant.growthStage.name,
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Analyze'),
                    ),
                  ],
                  if (state.status == PlantObservationStatus.analyzing)
                    const _Progress(label: 'Analyzing visible evidence…'),
                  if (state.status == PlantObservationStatus.saving)
                    const _Progress(label: 'Saving structured observation…'),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      key: const ValueKey('observation-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (state.result != null) ...[
                    const SizedBox(height: 20),
                    ObservationResultView(observation: state.result!),
                    if (state.status == PlantObservationStatus.saveFailure)
                      OutlinedButton.icon(
                        key: const ValueKey('retry-save'),
                        onPressed: () => context
                            .read<PlantObservationBloc>()
                            .add(PlantObservationSaveRetried(plantId)),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Retry saving'),
                      ),
                    if (state.status == PlantObservationStatus.success)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => context.go(
                              AppRoutes.observationHistory(plantId),
                            ),
                            child: const Text('View history'),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoGuidance extends StatelessWidget {
  const _PhotoGuidance();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Use good natural light and sharp focus. Fill the frame with one affected plant area. Avoid faces, documents, addresses, and other personal details.',
      ),
    ),
  );
}

class _PrivacyDisclosure extends StatelessWidget {
  const _PrivacyDisclosure();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Privacy: This image will be sent to Google\'s Gemini service for analysis. On the Gemini Developer API free tier, submitted content may be used by Google to improve its products. PlantCare AI will not save the image in cloud storage. Avoid photos containing faces, children, documents, addresses, or private home details.',
      ),
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
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
    ),
  );
}
